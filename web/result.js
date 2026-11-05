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
