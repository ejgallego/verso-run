import assert from "node:assert/strict";
import { normalizeResult } from "../web/result.js";
import { ResultView } from "../web/result-view.js";
import { scalarKind, presenterKey } from "../web/contract.js";

const moduleUrl = source => `data:text/javascript,${encodeURIComponent(source)}`;
const tick = () => new Promise(resolve => setImmediate(resolve));
async function until(predicate) {
  for (let i = 0; i < 100; ++i) { if (predicate()) return; await tick(); }
  assert.fail("Fixture did not reach its checkpoint");
}
const description = { program: "Fixture", declaration: "Fixture.packet", callable: "Fixture.packet",
  form: { input: "uint64", presenter: "Fixture.Packet" } };
assert.equal(scalarKind(description.form), "uint64");
assert.equal(presenterKey(description.form), "Fixture.Packet");
for (const form of [{input:"nat",presenter:""}, {input:"html",presenter:"Packet"},
    {input:"nat",presenter:"Packet", extra:true}, {input:"nat"}])
  assert.throws(() => scalarKind(form), /Unsupported/);

const normalizer = moduleUrl(`export function normalizeResult(value) {
  value.label = "owned";
  return { result:value, transfer:[value.bytes.buffer] };
}`);
const original = {label:"runtime", bytes:new Uint8Array([255,0])};
const packet = await normalizeResult(normalizer, original, description);
assert.equal(original.label, "runtime");
const posted = structuredClone(packet.result, {transfer:packet.transfer});
assert.deepEqual([...posted.bytes], [255,0]);
assert.deepEqual([...original.bytes], [255,0]);
assert.equal(packet.result.bytes.buffer.byteLength, 0);
for (const [body, reason] of [
  ["return value", /result, transfer/],
  ["return {result:value,transfer:value.bytes.buffer}", /unique ArrayBuffers/],
  ["return {result:value,transfer:[value.bytes.buffer,value.bytes.buffer]}", /unique ArrayBuffers/],
  ["return {result:value,transfer:[new ArrayBuffer(4)]}", /reachable/],
]) await assert.rejects(normalizeResult(moduleUrl(`export function normalizeResult(value){${body}}`), original, description), reason);
const graph = await normalizeResult(moduleUrl(`export function normalizeResult(value) {
  const result = {map:new Map([[value.bytes, new Set([value.bytes.buffer])]])};
  result.self = result;
  return {result, transfer:[value.bytes.buffer]};
}`), original, description);
assert.equal(graph.result.self, graph.result);
assert.equal(graph.transfer.length, 1);
console.log("PASS custom input projection, owned clone and reachable unique transfers, including cyclic graphs");

const messages = [];
globalThis.onmessage = null;
globalThis.postMessage = (data, transfer = []) => messages.push(structuredClone(data, {transfer}));
globalThis.fixtureRaw = original;
let runtime = moduleUrl(`export async function createProgram(options) {
  globalThis.fixtureOptions = options;
  return {call(){return globalThis.fixtureRaw},dispose(){globalThis.fixtureDisposed=true}};
}`);
await import("../web/worker.js?custom-result-fixture");
const programRequest = {runtimeModule:runtime, runtimeManifest:"https://fixture/runtime.json",
  programManifest:"https://fixture/program.json", expectedExport:{independent:true},resultModule:normalizer};
await globalThis.onmessage({data:{operation:"invoke",requestId:1,description,programRequest,input:"255"}});
assert.deepEqual(globalThis.fixtureOptions.expectedExports, {"Fixture.packet":{independent:true}});
assert.equal(messages.at(-1).state, "success");
assert.deepEqual([...messages.at(-1).result.bytes], [255,0]);
assert.deepEqual([...original.bytes], [255,0]);
await globalThis.onmessage({data:{operation:"invoke",requestId:2,
  description:{...description,form:{input:"uint64",presenter:"Other"}},programRequest,input:"1"}});
assert.equal(messages.at(-1).state, "failed");
assert.match(messages.at(-1).error, /identity changed/);
assert.equal(globalThis.fixtureDisposed, true);
console.log("PASS stock worker forwards independent signatures and enforces custom-result identity without detaching runtime storage");

const counters = globalThis.fixtureRenderer = {mounts:0, shows:0, clear:0, pause:0, dispose:0, signals:[]};
const renderer = moduleUrl(`export function mount(slot, {signal}) {
  ++globalThis.fixtureRenderer.mounts;
  globalThis.fixtureRenderer.placement = signal;
  return {
    show(value,{signal}) { ++globalThis.fixtureRenderer.shows; globalThis.fixtureRenderer.signals.push(signal);
      return globalThis.fixtureRenderer.pending; },
    clear(){++globalThis.fixtureRenderer.clear}, pause(){++globalThis.fixtureRenderer.pause},
    dispose(){++globalThis.fixtureRenderer.dispose}
  };
}`);
const slot = {hidden:true, replaceChildren(){}};
const lifetime = new AbortController(), errors = [];
const view = new ResultView(slot, lifetime.signal, error => errors.push(error));
assert.equal(await view.show({bytes:[1]}, renderer), true);
const signal = counters.signals.at(-1);
view.pause();
assert.equal(signal.aborted, true);
assert.equal(counters.pause, 1);
assert.equal(await view.resume(), true);
assert.equal(counters.mounts, 1);
assert.equal(counters.signals.at(-1).aborted, false);
let release;
counters.pending = new Promise(resolve => {release=resolve});
const pending = view.show({bytes:[2]}, renderer);
await until(() => counters.signals.length === 3);
view.clear();
assert.equal(await pending, false);
assert.equal(counters.signals.at(-1).aborted, true);
release(); await tick();
assert.equal(view.hasValue, false);
assert.equal(slot.hidden, true);
lifetime.abort(); view.dispose();
assert.equal(counters.dispose, 1);
assert.deepEqual(errors, []);
console.log("PASS stable result slot, per-result abort before pause/clear, guarded pending show and placement disposal");

const timers = [], realSetTimeout = globalThis.setTimeout, realClearTimeout = globalThis.clearTimeout;
globalThis.setTimeout = (callback, delay, ...rest) => delay === 15000 ? (timers.push(callback), -1) : realSetTimeout(callback, delay, ...rest);
globalThis.clearTimeout = timer => {if (timer !== -1) realClearTimeout(timer)};
try {
  let finish;
  globalThis.fixtureImport = new Promise(resolve => {finish=resolve});
  const held = moduleUrl(`await globalThis.fixtureImport; export function mount(){ globalThis.lateMount=true; }`);
  const v = new ResultView(slot, new AbortController().signal, error => errors.push(error));
  const showing = v.show({}, held);
  await tick();
  timers.at(-1)();
  assert.equal(await showing, false);
  assert.match(errors.at(-1).message, /timed out/);
  finish(); await tick(); await tick();
  assert.equal(globalThis.lateMount, undefined);
  console.log("PASS held renderer import deadline settles without release and late completion cannot mount");

  let makeVisible;
  globalThis.fixtureHiddenImport = new Promise(resolve => {makeVisible=resolve});
  const delayed = moduleUrl(`await globalThis.fixtureHiddenImport; export {mount} from ${JSON.stringify(renderer)};`);
  const hidden = new ResultView(slot, new AbortController().signal, error => errors.push(error));
  const initial = hidden.show({bytes:[3]}, delayed);
  await tick();
  hidden.pause();
  assert.equal(await initial, false);
  assert.equal(hidden.hasValue, true);
  assert.equal(hidden.shown, false);
  counters.pending = undefined;
  const restored = hidden.resume();
  makeVisible();
  assert.equal(await restored, true);
  assert.equal(hidden.shown, true);
  assert.equal(slot.hidden, false);
  hidden.dispose();
  console.log("PASS hiding the first held renderer import retains the completed result and re-presents it on visibility");

  let rejectNormalization;
  globalThis.fixtureNormalization = new Promise((_, reject) => {rejectNormalization=reject});
  const delayedNormalizer = moduleUrl(`export const normalizeResult = () => globalThis.fixtureNormalization;`);
  const normalizing = normalizeResult(delayedNormalizer, original, description);
  await tick();
  timers.at(-1)();
  await assert.rejects(normalizing, /timed out/);
  rejectNormalization(new Error("Late normalizer failure"));
  await tick();
  console.log("PASS asynchronous normalization deadline settles and observes a late rejection");
} finally {
  globalThis.setTimeout = realSetTimeout;
  globalThis.clearTimeout = realClearTimeout;
}
