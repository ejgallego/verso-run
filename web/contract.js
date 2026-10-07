// Input and display policy for the two interfaces admitted by Lean Run.
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
export function formatResult(shape, result) {
  if (shape === "string" && typeof result !== "string") throw new Error("Lean returned an invalid String");
  if (shape === "nat" && !(typeof result === "bigint" && result >= 0n)) {
    throw new Error("Lean returned an invalid exact Nat");
  }
  const text = String(result);
  if (text.length > MAX_OUTPUT) throw new Error(`Result exceeds ${MAX_OUTPUT} UTF-16 code units`);
  return text;
}
