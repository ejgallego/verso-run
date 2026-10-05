// Reviewed adapter for exactly the two author interfaces admitted by VIR classification.
export const MAX_STRING = 4096;
export const MAX_NAT_DIGITS = 256;
export const MAX_OUTPUT = 65536;
export function validateInput(shape, value) {
  if (typeof value !== "string") throw new Error("Input must be text");
  if (shape === "string") {
    if (value.length > MAX_STRING) throw new Error(`Use at most ${MAX_STRING} UTF-16 code units`);
  } else if (shape === "nat") {
    if (!/^[0-9]+$/.test(value)) throw new Error("Enter a non-negative decimal natural number");
    if (value.length > MAX_NAT_DIGITS) throw new Error(`Use at most ${MAX_NAT_DIGITS} decimal digits`);
  } else throw new Error("Unsupported Lean Run interface");
  // Decimal text is VIR's exact Nat boundary representation. Never convert to Number.
  return value;
}
export function expectedExport(description) {
  const shape = description.shape;
  if (shape !== "string" && shape !== "nat") throw new Error("Unsupported Lean Run interface");
  const type = shape === "string" ? { type: "String", interfaceTag: 3 } : { type: "Nat", interfaceTag: 0 };
  return {
    declaration: description.declaration,
    interfaceId: `verso-${shape === "string" ? "string-string" : "nat-nat"}-v1`,
    signature: { args: [type], result: type, effect: "pure" },
  };
}
export function formatResult(shape, result) {
  if (shape === "string" && typeof result !== "string") throw new Error("Lean returned an invalid String");
  if (shape === "nat" && !((typeof result === "string" && /^[0-9]+$/.test(result)) ||
      (typeof result === "number" && Number.isSafeInteger(result) && result >= 0))) {
    throw new Error("Lean returned an invalid exact Nat");
  }
  const text = String(result);
  if (text.length > MAX_OUTPUT) throw new Error(`Result exceeds ${MAX_OUTPUT} UTF-16 code units`);
  return text;
}
