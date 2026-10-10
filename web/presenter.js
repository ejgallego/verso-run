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

// The visible document stays untouched until its replacement has loaded and
// had a rendering opportunity. Stop observes the same abort signal as loading.
function waitForPreview(frame, signal) {
  return new Promise((resolve, reject) => {
    let paint;
    const finish = error => {
      cancelAnimationFrame(paint);
      frame.removeEventListener("load", loaded);
      signal.removeEventListener("abort", aborted);
      if (error) reject(error); else resolve();
    };
    const aborted = () => finish(signal.reason);
    const loaded = () => {
      if (document.hidden) finish();
      else paint = requestAnimationFrame(() => {
        paint = requestAnimationFrame(() => finish());
      });
    };
    frame.addEventListener("load", loaded, { once: true });
    signal.addEventListener("abort", aborted, { once: true });
    if (signal.aborted) aborted();
  });
}

export class ViewHost {
  constructor(element, kind, onError) {
    if (!["html", "sequence", "automaton"].includes(kind)) throw new Error("Unsupported Lean view");
    this.element = element;
    this.kind = kind;
    this.onError = onError;
    this.generation = 0;
    this.program = null;
    this.cleanup = null;
    this.declaration = null;
    this.commit = null;
    this.controller = null;
  }
  clear() {
    ++this.generation;
    this.controller?.abort();
    this.controller = null;
    const cleanup = this.cleanup, program = this.program;
    this.cleanup = null;
    this.program = null;
    this.declaration = null;
    this.commit = null;
    let failure;
    try { cleanup?.(); } catch (error) { failure = error; }
    try { program?.dispose(); } catch (error) { failure ??= error; }
    this.element.replaceChildren();
    if (this.kind === "html") this.element.removeAttribute("srcdoc");
    this.element.hidden = true;
    // Cleanup must never prevent the host from settling Stop or disposal.
    if (failure) console.error("View cleanup failed", failure);
  }
  async commitFrame(frame, generation, signal) {
    const next = this.element.querySelector('[data-preview="next"]');
    if (!next) throw new Error("Missing staged automaton preview");
    await waitForPreview(next, signal);
    if (generation !== this.generation) return false;
    const result = this.program.call(this.commit, this.element, frame);
    if (result !== undefined) throw new Error("Automaton commit returned an invalid Unit");
    return true;
  }
  async update(frame) {
    if (this.kind !== "automaton" || !this.program) throw new Error("No live presenter to update");
    if (this.controller) throw new Error("A frame is already being presented");
    const generation = this.generation;
    const controller = this.controller = new AbortController();
    const deadline = setTimeout(() => controller.abort(
      new Error("Frame loading timed out. Try Run again.")), 15000);
    try {
      const result = this.program.call(this.declaration, this.element, frame);
      if (result !== undefined) throw new Error("Automaton presenter returned an invalid Unit");
      return await this.commitFrame(frame, generation, controller.signal);
    } catch (error) {
      if (generation !== this.generation) return false;
      this.clear();
      this.onError(error);
      return false;
    } finally {
      clearTimeout(deadline);
      if (this.controller === controller) this.controller = null;
    }
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
      if (this.kind === "automaton" && !presenter.commit?.expectedExport) {
        throw new Error("No published automaton commit contract");
      }
      const expectedExports = { [presenter.declaration]: presenter.expectedExport };
      if (this.kind === "automaton") expectedExports[presenter.commit.declaration] = presenter.commit.expectedExport;
      const url = path => new URL(path, new URL("../", import.meta.url));
      const { createProgram } = await waitForModule(
        import(url(plan.runtimeModule).href), controller.signal);
      if (generation !== this.generation) return false;
      if (controller.signal.aborted) throw controller.signal.reason;
      program = await createProgram({ runtimeManifestUrl: url(plan.runtimeManifest),
        programManifestUrl: url(presenter.manifest), signal: controller.signal,
        expectedExports });
      if (generation !== this.generation) { program.dispose(); return false; }
      this.program = program;
      this.declaration = presenter.declaration;
      this.commit = presenter.commit?.declaration;
      const cleanup = program.call(presenter.declaration, this.element, data);
      if (this.kind === "sequence") {
        if (typeof cleanup !== "function") throw new Error("Sequence presenter did not return its cleanup callback");
        this.cleanup = cleanup;
      } else if (cleanup !== undefined) throw new Error("View presenter returned an invalid Unit");
      if (this.kind === "automaton" && !await this.commitFrame(data, generation, controller.signal)) return false;
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
