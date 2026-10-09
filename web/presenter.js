// The Lean/VIR presenter owns selection, controls and event listeners.
// This bridge owns asynchronous acquisition and the placement's lifetime.
function waitForModule(imported, signal) {
  let abort;
  const cancelled = new Promise((_, reject) => {
    abort = () => reject(signal.reason);
    if (signal.aborted) abort();
    else signal.addEventListener("abort", abort, { once: true });
  });
  // Import itself can continue and evaluate. The race keeps observing its late
  // rejection, while only our wait settles on Stop or the loading deadline.
  return Promise.race([imported, cancelled]).finally(() =>
    signal.removeEventListener("abort", abort));
}

export class ViewHost {
  constructor(element, kind, onError) {
    if (!["html", "sequence"].includes(kind)) throw new Error("Unsupported Lean view");
    this.element = element;
    this.kind = kind;
    this.onError = onError;
    this.generation = 0;
    this.program = null;
    this.cleanup = null;
    this.controller = null;
  }
  clear() {
    ++this.generation;
    this.controller?.abort();
    this.controller = null;
    const cleanup = this.cleanup, program = this.program;
    this.cleanup = null;
    this.program = null;
    let failure;
    try { cleanup?.(); } catch (error) { failure = error; }
    try { program?.dispose(); } catch (error) { failure ??= error; }
    this.element.replaceChildren();
    if (this.kind === "html") this.element.removeAttribute("srcdoc");
    this.element.hidden = true;
    // Cleanup must never prevent the host from settling Stop or disposal.
    if (failure) console.error("View cleanup failed", failure);
  }
  async show(data) {
    this.clear();
    const generation = this.generation;
    const controller = this.controller = new AbortController();
    let program;
    const deadline = setTimeout(() => controller.abort(
      new Error("View loading timed out. Try Run again.")), 15000);
    try {
      const response = await fetch(new URL("./publication.json", import.meta.url), { signal: controller.signal });
      if (!response.ok) throw new Error(`View publication: HTTP ${response.status}`);
      const plan = await response.json();
      const presenter = plan.presenters?.[this.kind];
      if (!presenter?.expectedExport) throw new Error(`No published ${this.kind} presenter contract`);
      const url = path => new URL(path, new URL("../", import.meta.url));
      const { createProgram } = await waitForModule(
        import(url(plan.runtimeModule).href), controller.signal);
      if (generation !== this.generation) return false;
      if (controller.signal.aborted) throw controller.signal.reason;
      program = await createProgram({ runtimeManifestUrl: url(plan.runtimeManifest),
        programManifestUrl: url(presenter.manifest), signal: controller.signal,
        expectedExports: { [presenter.declaration]: presenter.expectedExport } });
      if (generation !== this.generation) { program.dispose(); return false; }
      this.program = program;
      const cleanup = program.call(presenter.declaration, this.element, data);
      if (this.kind === "sequence") {
        if (typeof cleanup !== "function") throw new Error("Sequence presenter did not return its cleanup callback");
        this.cleanup = cleanup;
      } else if (cleanup !== undefined) throw new Error("HTML presenter returned an invalid Unit");
      this.element.hidden = false;
      this.controller = null;
      return true;
    } catch (error) {
      if (generation !== this.generation) return false;
      const failure = controller.signal.aborted ? controller.signal.reason : error;
      this.clear();
      const details = [];
      for (let current = failure, i = 0; current && i < 5; current = current.cause, ++i) {
        details.push(String(current.message ?? current).slice(0, 1000));
      }
      this.onError(new Error(details.join(": ")));
      return false;
    } finally { clearTimeout(deadline); }
  }
}
