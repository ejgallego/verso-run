import { validateInput } from "./contract.js";
let publication;
async function publishedPrograms() {
  publication ??= fetch(new URL("./publication.json", import.meta.url)).then(async response => {
    if (!response.ok) throw new Error(`Lean Run publication: HTTP ${response.status}`);
    return response.json();
  }).catch(error => { publication = undefined; throw error; });
  return publication;
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
    if (this.disposed) throw new Error("Experiment is disposed");
    if (this.pending) throw new Error("Experiment is already running");
    validateInput(this.description.shape, input);
    const generation = this.generation;
    const requestId = ++this.request;
    let resolve, reject;
    const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
    promise.catch(() => {}); // Observe cancellation even while publication loading is pending.
    this.pending = { requestId, resolve, reject };
    this.onState("loading");
    try {
      const plan = await publishedPrograms();
      if (generation !== this.generation) return await promise;
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
          if (data.state === "running") { this.onState("running"); return; }
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
      this.worker.postMessage({ operation: "invoke", requestId, description: this.description, publication, input });
    } catch (error) {
      if (generation === this.generation && this.pending?.requestId === requestId) this.fail(error);
    }
    return await promise;
  }
  fail(error) {
    const pending = this.pending;
    this.pending = null;
    this.worker?.terminate();
    this.worker = null;
    this.onState("failed", String(error.message ?? error));
    pending?.reject(error);
  }
  stop(state = "stopped") {
    ++this.generation;
    const pending = this.pending;
    this.pending = null;
    this.worker?.terminate();
    this.worker = null;
    this.onState(state);
    pending?.reject(new DOMException("Execution stopped", "AbortError"));
  }
  dispose() { this.disposed = true; this.stop("stopped"); }
}
