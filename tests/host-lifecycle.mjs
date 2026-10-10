import assert from "node:assert/strict";

const description = { program: "Test", declaration: "Test.echo", callable: "Test.echo", form: "string" };
const signature = { args: [{ type: "String", interfaceTag: 3 }],
  result: { type: "String", interfaceTag: 3 }, effect: "pure" };
const plan = { runtimeModule: "runtime.js", runtimeManifest: "runtime.json",
  programs: { Test: { "Test.echo": { manifest: "program.json", expectedExport: signature } } } };
const realSetTimeout = globalThis.setTimeout;
const realClearTimeout = globalThis.clearTimeout;
const checks = [];
const tick = () => new Promise(resolve => realSetTimeout(resolve, 0));
async function promptly(promise) {
  let timer;
  try {
    return await Promise.race([promise, new Promise((_, reject) => {
      timer = realSetTimeout(() => reject(new Error("Invocation remained pending")), 250);
    })]);
  } finally { realClearTimeout(timer); }
}
const outcome = promise => promise.then(value => ({ value }), error => ({ error }));
let caseId = 0;
async function fixture({ honorAbort = true, holdWorker = false, experiment = description } = {}) {
  const requests = [], workers = [];
  globalThis.fetch = (url, { signal } = {}) => new Promise((resolve, reject) => {
    requests.push({ signal, reject,
      reply: (body = plan, status = 200) => resolve({ ok: status === 200, status,
        json: async () => body }),
      badJson: () => resolve({ ok: true, json: async () => { throw new SyntaxError("bad JSON"); } }) });
    if (honorAbort) signal?.addEventListener("abort", () => reject(signal.reason), { once: true });
  });
  globalThis.Worker = class {
    constructor() { workers.push(this); }
    postMessage(data) {
      (this.messages ??= []).push(data);
      if (!holdWorker) queueMicrotask(() => this.onmessage({ data: {
        requestId: data.requestId, state: "success", result: data.input } }));
    }
    terminate() { this.terminated = true; }
  };
  const { ExperimentHost } = await import(`../web/host.js?lifecycle=${++caseId}`);
  return { requests, workers, host: onState => new ExperimentHost(experiment, onState) };
}
async function test(name, run) { await run(); checks.push(name); console.log("PASS", name); }

await test("Stop settles before publication responds; retry starts fresh; late success creates no stale worker", async () => {
  const { requests, workers, host } = await fixture({ honorAbort: false });
  const h = host(), first = outcome(h.invoke("first"));
  h.stop();
  assert.equal((await promptly(first)).error.name, "AbortError");
  assert.equal(workers.length, 0);
  assert.equal(requests[0].signal.aborted, true);
  // Do not release the first response before checking prompt cancellation and retry.
  const retry = h.invoke("retry");
  assert.equal(requests.length, 2);
  requests[1].reply();
  assert.equal(await promptly(retry), "retry");
  requests[0].reply();
  await tick();
  assert.equal(workers.length, 1);
  assert.equal(await h.invoke("cached"), "cached");
  assert.equal(requests.length, 2);
  h.dispose();
});

await test("Stopping one simultaneous placement preserves the other's shared acquisition", async () => {
  const { requests, workers, host } = await fixture();
  const a = host(), b = host();
  const first = outcome(a.invoke("first")), second = b.invoke("second");
  assert.equal(requests.length, 1);
  a.stop();
  assert.equal((await promptly(first)).error.name, "AbortError");
  assert.equal(requests[0].signal.aborted, false);
  assert.equal(workers.length, 0);
  requests[0].reply();
  assert.equal(await promptly(second), "second");
  assert.equal(await a.invoke("retry"), "retry");
  assert.equal(workers.length, 2);
  assert.equal(requests.length, 1);
  a.dispose(); b.dispose();
});

await test("Cancelling all waiters releases acquisition; late failure cannot evict a newer cached plan", async () => {
  const { requests, host } = await fixture({ honorAbort: false });
  const a = host(), b = host();
  const first = outcome(a.invoke("first")), second = outcome(b.invoke("second"));
  a.stop(); b.stop();
  for (const result of await Promise.all([promptly(first), promptly(second)])) {
    assert.equal(result.error.name, "AbortError");
  }
  assert.equal(requests[0].signal.aborted, true);
  const retry = a.invoke("retry"); requests[1].reply();
  assert.equal(await promptly(retry), "retry");
  requests[0].reject(new Error("abandoned fetch failed late"));
  await tick();
  assert.equal(await b.invoke("cached"), "cached");
  assert.equal(requests.length, 2);
  a.dispose(); b.dispose();
});

await test("Disposal promptly rejects loading and prevents further invocation", async () => {
  const { requests, workers, host } = await fixture();
  const h = host(), pending = outcome(h.invoke("disposed"));
  h.dispose();
  assert.equal((await promptly(pending)).error.name, "AbortError");
  assert.equal(requests[0].signal.aborted, true);
  assert.equal(workers.length, 0);
  await assert.rejects(h.invoke("later"), /disposed/);
  await tick();
});

for (const failure of ["HTTP", "JSON"]) await test(`${failure} failure settles without a worker or automatic replay; explicit retry reacquires`, async () => {
  const { requests, workers, host } = await fixture();
  const h = host(), pending = outcome(h.invoke("bad"));
  if (failure === "HTTP") requests[0].reply(null, 503); else requests[0].badJson();
  assert.match((await promptly(pending)).error.message, failure === "HTTP" ? /HTTP 503/ : /bad JSON/);
  await tick();
  assert.equal(workers.length, 0);
  assert.equal(requests.length, 1);
  const retry = h.invoke("recovered"); requests[1].reply();
  assert.equal(await promptly(retry), "recovered");
  h.dispose();
});

await test("A publication deadline fails all waiting placements and allows explicit recovery", async () => {
  const timers = new Map(); let nextTimer = 0;
  globalThis.setTimeout = callback => { timers.set(++nextTimer, callback); return nextTimer; };
  globalThis.clearTimeout = id => timers.delete(id);
  try {
    const { requests, workers, host } = await fixture();
    const a = host(), b = host();
    const first = outcome(a.invoke("first")), second = outcome(b.invoke("second"));
    assert.equal(timers.size, 1);
    [...timers.values()][0]();
    for (const result of await Promise.all([promptly(first), promptly(second)])) {
      assert.match(result.error.message, /publication timed out.*Run to retry/);
    }
    assert.equal(workers.length, 0);
    assert.equal(timers.size, 0);
    const retry = a.invoke("recovered"); requests[1].reply();
    assert.equal(await promptly(retry), "recovered");
    assert.equal(requests.length, 2);
    assert.equal(timers.size, 0);
    a.dispose(); b.dispose();
  } finally {
    globalThis.setTimeout = realSetTimeout;
    globalThis.clearTimeout = realClearTimeout;
  }
});

await test("Automaton advance reuses the worker; Stop settles held work and ignores late frames; restart owns a fresh session", async () => {
  const { requests, workers, host } = await fixture({ holdWorker: true,
    experiment: {...description, form: "automaton"} });
  const states = [], h = host((state, value) => states.push([state, value]));
  const reply = (worker, result) => worker.onmessage({data: {
    requestId: worker.messages.at(-1).requestId, state: "success", result }});
  const initial = h.invoke("seed"); requests[0].reply(); await tick();
  reply(workers[0], "initial"); assert.equal(await initial, "initial");
  const held = outcome(h.advance()); await tick();
  assert.equal(workers[0].messages.at(-1).operation, "advance");
  await assert.rejects(h.advance(), /already running/);
  h.stop(); assert.equal((await promptly(held)).error.name, "AbortError");
  assert.equal(workers[0].terminated, true);
  reply(workers[0], "late"); assert.equal(states.at(-1)[0], "stopped");
  const restarted = h.invoke("new seed"); await tick();
  assert.equal(workers.length, 2);
  reply(workers[1], "new initial"); assert.equal(await restarted, "new initial");
  const next = h.advance(); await tick(); reply(workers[1], "next");
  assert.equal(await next, "next"); assert.equal(workers.length, 2);
  h.dispose();
});
console.log(JSON.stringify({ checks, count: checks.length }));
