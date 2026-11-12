import { validateInput, scalarKind, resultKind } from "./contract.js";
import { siteBackend } from "./backend.js";
// Each placement owns a host. Resource bytes can be shared; program state never is.
export class ExperimentHost {
  constructor(description, onState = () => {}, backend = siteBackend) {
    this.backend = backend;
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
    const controller = new AbortController();
    const acquisition = this.backend.acquireCall(this.description, controller.signal);
    this.pending = { requestId, operation, resolve, reject, release: acquisition.release, controller };
    this.onState(operation === "advance" ? "advancing" : "loading");
    void (async () => {
      try {
        const resources = await acquisition.promise;
        if (generation !== this.generation || this.pending?.requestId !== requestId) return;
        const programRequest = resources.programRequest;
        this.resultRendererUrl = resources.resultRendererUrl;
        if (!this.worker) {
          const worker = this.backend.createWorker();
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
        this.worker.postMessage({ operation, requestId, description: this.description, programRequest, input });
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
    pending?.controller.abort();
    pending?.release();
    this.worker?.terminate();
    this.worker = null;
    try { this.onState("failed", String(error.message ?? error)); }
    finally { pending?.reject(error); }
  }
  stop(state = "stopped") {
    ++this.generation;
    const pending = this.pending;
    this.pending = null;
    pending?.controller.abort();
    pending?.release();
    this.worker?.terminate();
    this.worker = null;
    try { this.onState(state); }
    finally { pending?.reject(new DOMException("Execution stopped", "AbortError")); }
  }
  dispose() { this.disposed = true; this.stop("stopped"); }
}
