import { validateInput, scalarKind, resultKind } from "./contract.js";
let publication;
// Pending acquisition is shared only while a placement still needs it. A stopped
// placement releases its interest, without aborting another placement's fetch.
function acquirePublication() {
  if (!publication) {
    const controller = new AbortController();
    const entry = { controller, users: 0, settled: false };
    publication = entry;
    const deadline = setTimeout(() => controller.abort(
      new Error("Lean Run publication timed out. Choose Run to retry.")), 15000);
    entry.promise = fetch(new URL("./publication.json", import.meta.url),
      { signal: controller.signal }).then(async response => {
      if (!response.ok) throw new Error(`Lean Run publication: HTTP ${response.status}`);
      return response.json();
    }).catch(error => {
      // A late failure of abandoned acquisition cannot evict a successful retry.
      if (publication === entry) publication = undefined;
      throw error;
    }).finally(() => {
      entry.settled = true;
      clearTimeout(deadline);
    });
  }
  const entry = publication;
  ++entry.users;
  let released = false;
  return { promise: entry.promise, release() {
    if (released) return;
    released = true;
    if (--entry.users === 0 && !entry.settled) {
      if (publication === entry) publication = undefined;
      entry.controller.abort();
    }
  } };
}
// Each placement owns a host. Resource bytes can be shared; program state never is.
export class ExperimentHost {
  constructor(description, onState = () => {}) {
    this.description = description;
    this.onState = onState;
    this.worker = null;
    this.generation = 0;
    this.request = 0;
    this.pending = null;
    this.disposed = false;
  }
  async invoke(input) {
    validateInput(scalarKind(this.description.form), input);
    if (resultKind(this.description.form) === "automaton" && this.worker && !this.pending) this.stop("idle");
    return this.requestOperation("invoke", input);
  }
  advance() {
    if (resultKind(this.description.form) !== "automaton" || !this.worker) {
      return Promise.reject(new Error("No automaton session to advance"));
    }
    return this.requestOperation("advance");
  }
  async requestOperation(operation, input) {
    if (this.disposed) throw new Error("Experiment is disposed");
    if (this.pending) throw new Error("Experiment is already running");
    const generation = this.generation;
    const requestId = ++this.request;
    let resolve, reject;
    const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
    const acquisition = acquirePublication();
    this.pending = { requestId, operation, resolve, reject, release: acquisition.release };
    this.onState(operation === "advance" ? "advancing" : "loading");
    void (async () => {
      try {
        const plan = await acquisition.promise;
        if (generation !== this.generation || this.pending?.requestId !== requestId) return;
        const binding = plan.programs[this.description.program]?.[this.description.declaration];
        if (!binding) throw new Error(`No published program for ${this.description.declaration}`);
        if (!binding.expectedExport) throw new Error(`No published VIR signature for ${this.description.declaration}`);
        const url = path => new URL(path, new URL("../", import.meta.url)).href;
        const publication = { runtimeModule: url(plan.runtimeModule),
          runtimeManifest: url(plan.runtimeManifest), programManifest: url(binding.manifest),
          expectedExport: binding.expectedExport };
        if (!this.worker) {
          const worker = new Worker(new URL("./worker.js", import.meta.url), { type: "module" });
          this.worker = worker;
          worker.onmessage = ({ data }) => {
            if (worker !== this.worker || generation !== this.generation || data.requestId !== this.pending?.requestId) return;
            if (data.state === "running") { this.onState(this.pending.operation === "advance" ? "advancing" : "running"); return; }
            const pending = this.pending;
            this.pending = null;
            if (data.state === "success") {
              this.onState("success", data.result);
              pending.resolve(data.result);
            } else {
              this.worker = null;
              worker.terminate();
              this.onState("failed", data.error);
              pending.reject(new Error(data.error));
            }
          };
          worker.onerror = event => {
            if (worker !== this.worker || generation !== this.generation) return;
            event.preventDefault();
            this.fail(new Error(event.message || "Lean Run worker failed"));
          };
        }
        this.worker.postMessage({ operation, requestId, description: this.description, publication, input });
      } catch (error) {
        if (generation === this.generation && this.pending?.requestId === requestId) this.fail(error);
      } finally {
        acquisition.release();
      }
    })();
    // Return independently of setup: Stop must settle even before a response arrives.
    return promise;
  }
  fail(error) {
    const pending = this.pending;
    this.pending = null;
    pending?.release();
    this.worker?.terminate();
    this.worker = null;
    this.onState("failed", String(error.message ?? error));
    pending?.reject(error);
  }
  stop(state = "stopped") {
    ++this.generation;
    const pending = this.pending;
    this.pending = null;
    pending?.release();
    this.worker?.terminate();
    this.worker = null;
    this.onState(state);
    pending?.reject(new DOMException("Execution stopped", "AbortError"));
  }
  dispose() { this.disposed = true; this.stop("stopped"); }
}
