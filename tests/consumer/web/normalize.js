export function normalizeResult(value) {
  if (!value || typeof value.label !== "string" || !(value.bytes instanceof Uint8Array) || value.bytes.length !== 2)
    throw new Error("Invalid packet");
  return { result: value, transfer: [value.bytes.buffer] };
}
