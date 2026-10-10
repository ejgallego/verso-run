// The finite wire names are checked against Lean's typed form model.
const FORMS = Object.freeze({
  string: {input: "string", result: "string"},
  multilineString: {input: "string", result: "string"},
  nat: {input: "nat", result: "nat"},
  bool: {input: "bool", result: "bool"},
  uint64: {input: "uint64", result: "uint64"},
  html: {input: "string", result: "string"},
  multilineHtml: {input: "string", result: "string"},
  sequence: {input: "string", result: "sequence"},
  multilineSequence: {input: "string", result: "sequence"},
  natHtml: {input: "nat", result: "string"},
  boolHtml: {input: "bool", result: "string"},
  uint64Html: {input: "uint64", result: "string"},
  natSequence: {input: "nat", result: "sequence"},
  boolSequence: {input: "bool", result: "sequence"},
  uint64Sequence: {input: "uint64", result: "sequence"},
  automaton: {input: "string", result: "automaton"},
  multilineAutomaton: {input: "string", result: "automaton"},
  natAutomaton: {input: "nat", result: "automaton"},
  boolAutomaton: {input: "bool", result: "automaton"},
  uint64Automaton: {input: "uint64", result: "automaton"},
});
function description(form) {
  if (typeof form !== "string" || !Object.hasOwn(FORMS, form)) throw new Error("Unsupported Lean Run form");
  return FORMS[form];
}
export function scalarKind(form) { return description(form).input; }
export function resultKind(form) { return description(form).result; }
// Concrete scalar form policy, shared by the host and its worker.
export const MAX_STRING = 4096;
export const MAX_NAT_DIGITS = 256;
export const MAX_OUTPUT = 65536;
export const MAX_UINT64 = (1n << 64n) - 1n;
export const MAX_FRAMES = 128;
export function formatPublishedResult(form, result) {
  const kind = resultKind(form);
  if (kind === "automaton") { validateFrame(result); return result; }
  if (kind !== "sequence") return formatResult(kind, result);
  if (!result || result.version !== 1n || !Array.isArray(result.frames) ||
      result.frames.length < 1 || result.frames.length > MAX_FRAMES) {
    throw new Error("Lean returned an invalid sequence presentation");
  }
  let size = 0;
  for (const frame of result.frames) {
    size += validateFrame(frame);
    if (size > MAX_OUTPUT) throw new Error(`Result exceeds ${MAX_OUTPUT} UTF-16 code units`);
  }
  return result;
}
function validateFrame(frame) {
  if (!frame || typeof frame.label !== "string" || typeof frame.html !== "string" ||
      !(frame.error === null || typeof frame.error === "string")) {
    throw new Error("Lean returned an invalid sequence frame");
  }
  const size = frame.label.length + frame.html.length + (frame.error?.length ?? 0);
  if (size > MAX_OUTPUT) throw new Error(`Result exceeds ${MAX_OUTPUT} UTF-16 code units`);
  return size;
}
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
