import { waitForSignal } from "./lifetime.js";

// A renderer owns only the persistent result slot. The synchronous placement
// owner retains controls, workers, state transitions and every async lifetime.
export class ResultView {
  constructor(slot, signal, onError) {
    this.slot = slot;
    this.signal = signal;
    this.onError = onError;
    this.renderer = null;
    this.controller = null;
    this.generation = 0;
    this.value = undefined;
    this.hasValue = false;
    this.shown = false;
    this.paused = false;
  }
  retire() {
    ++this.generation;
    this.controller?.abort(new DOMException("Result retired", "AbortError"));
    this.controller = null;
  }
  cleanup(method) {
    try { this.renderer?.[method](); }
    catch (error) { console.error(`Result presenter ${method} failed`, error); }
  }
  clear() {
    this.retire();
    this.hasValue = false;
    this.shown = false;
    this.value = undefined;
    this.cleanup("clear");
    this.slot.hidden = true;
  }
  pause() {
    this.paused = true;
    this.retire();
    this.cleanup("pause");
  }
  resume() {
    this.paused = false;
    return this.hasValue && !this.controller ? this.show(this.value, this.moduleUrl) : Promise.resolve(false);
  }
  dispose() {
    this.rendererController?.abort(new DOMException("Presenter disposed", "AbortError"));
    this.clear();
    this.cleanup("dispose");
    this.renderer = null;
    this.slot.replaceChildren();
  }
  async show(value, moduleUrl) {
    this.retire();
    // Worker completion survives a hidden tab, including before the first
    // module has loaded. Visibility can re-present it with a fresh signal.
    this.value = value;
    this.hasValue = true;
    this.moduleUrl = moduleUrl;
    if (this.paused) return false;
    const generation = this.generation;
    const controller = this.controller = new AbortController();
    const abort = () => controller.abort(this.signal.reason);
    this.signal.addEventListener("abort", abort, { once: true });
    if (this.signal.aborted) abort();
    const deadline = setTimeout(() => controller.abort(new Error("Result presentation timed out. Try Run again.")), 15000);
    try {
      if (!this.renderer) {
        const { mount } = await waitForSignal(import(moduleUrl), controller.signal);
        if (controller.signal.aborted) throw controller.signal.reason;
        if (typeof mount !== "function") throw new Error("Result presenter must export mount(slot, { signal })");
        const scope = new AbortController();
        let renderer;
        try { renderer = mount(this.slot, { signal: AbortSignal.any([this.signal, scope.signal]) }); }
        catch (error) { scope.abort(); this.slot.replaceChildren(); throw error; }
        if (!renderer || ["show", "clear", "pause", "dispose"].some(key => typeof renderer[key] !== "function")) {
          try { renderer?.dispose?.(); } catch {}
          scope.abort();
          this.slot.replaceChildren();
          throw new Error("Result presenter mount must return show, clear, pause and dispose hooks");
        }
        this.renderer = renderer;
        this.rendererController = scope;
      }
      await waitForSignal(Promise.resolve(this.renderer.show(value, { signal: controller.signal })), controller.signal);
      if (generation !== this.generation) return false;
      this.value = value;
      this.hasValue = true;
      this.shown = true;
      this.slot.hidden = false;
      return true;
    } catch (error) {
      if (generation !== this.generation || this.signal.aborted) return false;
      const failure = controller.signal.aborted ? controller.signal.reason : error;
      this.clear();
      this.onError(failure);
      return false;
    } finally {
      clearTimeout(deadline);
      this.signal.removeEventListener("abort", abort);
    }
  }
}
