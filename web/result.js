import { waitForSignal } from "./lifetime.js";

// Trusted author code receives an owned copy, never a runtime-owned backing
// store. Successful posting can transfer only buffers reachable from its result.
export async function normalizeResult(moduleUrl, value, description) {
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(new Error("Result normalization timed out. Try Run again.")), 15000);
  try {
  const adapter = await waitForSignal(import(moduleUrl), controller.signal);
  if (typeof adapter.normalizeResult !== "function")
    throw new Error("Result presenter must export normalizeResult(value, description)");
  const adapted = await waitForSignal(Promise.resolve(adapter.normalizeResult(structuredClone(value), description)), controller.signal);
  if (!adapted || typeof adapted !== "object" || !Object.hasOwn(adapted, "result"))
    throw new Error("Result presenter must return { result, transfer? }");
  const transfer = adapted.transfer ?? [];
  if (!Array.isArray(transfer) || transfer.some(buffer => !(buffer instanceof ArrayBuffer)) ||
      new Set(transfer).size !== transfer.length)
    throw new Error("Result presenter transfer list must contain unique ArrayBuffers");
  const buffers = new Set(), visited = new Set(), pending = [adapted.result];
  while (pending.length) {
    const value = pending.pop();
    if (!value || typeof value !== "object" || visited.has(value)) continue;
    visited.add(value);
    if (value instanceof ArrayBuffer) buffers.add(value);
    else if (ArrayBuffer.isView(value)) buffers.add(value.buffer);
    else if (value instanceof Map) for (const [key, item] of value) pending.push(key, item);
    else if (value instanceof Set) for (const item of value) pending.push(item);
    else for (const item of Object.values(value)) pending.push(item);
  }
  if (transfer.some(buffer => !buffers.has(buffer)))
    throw new Error("Result presenter transfer buffers must be reachable from result");
  return { result: adapted.result, transfer };
  } finally { clearTimeout(deadline); }
}

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
    this.value = undefined;
    this.cleanup("clear");
    this.slot.hidden = true;
  }
  pause() {
    this.retire();
    this.cleanup("pause");
  }
  resume() {
    return this.hasValue && !this.controller ? this.show(this.value) : Promise.resolve(false);
  }
  dispose() {
    this.clear();
    this.cleanup("dispose");
    this.renderer = null;
    this.slot.replaceChildren();
  }
  async show(value, moduleUrl) {
    this.retire();
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
        const renderer = mount(this.slot, { signal: this.signal });
        if (!renderer || ["show", "clear", "pause", "dispose"].some(key => typeof renderer[key] !== "function")) {
          try { renderer?.dispose?.(); } catch {}
          throw new Error("Result presenter mount must return show, clear, pause and dispose hooks");
        }
        this.renderer = renderer;
      }
      await waitForSignal(Promise.resolve(this.renderer.show(value, { signal: controller.signal })), controller.signal);
      if (generation !== this.generation) return false;
      this.value = value;
      this.hasValue = true;
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
