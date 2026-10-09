// Closed form names match the build-validated Lean FormKind.
export function scalarKind(form) {
  if (["string", "multilineString", "html", "multilineHtml"].includes(form)) return "string";
  if (["nat", "bool", "uint64"].includes(form)) return form;
  throw new Error("Unsupported Lean Run form");
}
// Concrete scalar form policy, shared by the host and its worker.
export const MAX_STRING = 4096;
export const MAX_NAT_DIGITS = 256;
export const MAX_OUTPUT = 65536;
export const MAX_UINT64 = (1n << 64n) - 1n;
export function validateInput(shape, value) {
  if (typeof value !== "string") throw new Error("Input must be text");
  if (shape === "string") {
    if (value.length > MAX_STRING) throw new Error(`Use at most ${MAX_STRING} UTF-16 code units`);
  } else if (shape === "nat" || shape === "uint64") {
    if (!/^[0-9]+$/.test(value)) throw new Error("Enter a non-negative decimal natural number");
    if (value.length > MAX_NAT_DIGITS) throw new Error(`Use at most ${MAX_NAT_DIGITS} decimal digits`);
    if (shape === "uint64" && BigInt(value) > MAX_UINT64) {
      throw new Error(`Enter an unsigned 64-bit integer from 0 to ${MAX_UINT64}`);
    }
  } else if (shape === "bool") {
    if (value !== "true" && value !== "false") throw new Error("Choose true or false");
  } else throw new Error("Unsupported Lean Run interface");
  // Decimal text is VIR's exact Nat boundary representation. Never convert to Number.
  return value;
}
export function decodeInput(shape, value) {
  validateInput(shape, value);
  if (shape === "bool") return value === "true";
  if (shape === "uint64") return BigInt(value);
  return value;
}
export function formatResult(shape, result) {
  if (!["string", "nat", "bool", "uint64"].includes(shape)) throw new Error("Unsupported Lean Run interface");
  if (shape === "string" && typeof result !== "string") throw new Error("Lean returned an invalid String");
  if (shape === "nat" && !(typeof result === "bigint" && result >= 0n)) {
    throw new Error("Lean returned an invalid exact Nat");
  }
  if (shape === "bool" && typeof result !== "boolean") throw new Error("Lean returned an invalid Bool");
  if (shape === "uint64" && !(typeof result === "bigint" && result >= 0n && result <= MAX_UINT64)) {
    throw new Error("Lean returned an invalid exact UInt64");
  }
  const text = String(result);
  if (text.length > MAX_OUTPUT) throw new Error(`Result exceeds ${MAX_OUTPUT} UTF-16 code units`);
  return text;
}
