import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { scalarKind, resultKind, decodeInput, formatPublishedResult } from "../web/contract.js";

// Consume Lean's emitted tags and compiler contracts, rather than duplicating
// the admitted form list in JavaScript.
const forms = JSON.parse(readFileSync(process.argv[2], "utf8"));
const scalars = {
  String: { kind: "string", input: "<b>& λ\ntext", decoded: "<b>& λ\ntext", result: "<b>& λ\ntext" },
  Nat: { kind: "nat", input: "9007199254740993", decoded: "9007199254740993", result: 9007199254740993n },
  Bool: { kind: "bool", input: "false", decoded: false, result: false },
  UInt64: { kind: "uint64", input: "18446744073709551615", decoded: 18446744073709551615n, result: 18446744073709551615n },
};
assert.ok(forms.length > 0);
assert.equal(new Set(forms.map(({ form }) => form)).size, forms.length);
const covered = new Set();
for (const { form, expectedExport } of forms) {
  assert.equal(typeof form, "string");
  assert.equal(expectedExport.effect, "pure");
  assert.equal(expectedExport.args.length, 1);
  const type = expectedExport.args[0].type;
  assert.ok(Object.hasOwn(scalars, type), `unsupported input ABI: ${type}`);
  const { kind, input, decoded, result } = scalars[type];
  assert.equal(scalarKind(form), kind, `input wire projection for ${form}`);
  assert.equal(decodeInput(scalarKind(form), input), decoded);
  if (resultKind(form) === "sequence") {
    assert.equal(expectedExport.result.kind, "structure");
    assert.equal(expectedExport.result.name, "VersoLeanRun.SequenceWire.Payload");
    const payload = { version: 1n, frames: [{ label: input, html: "<p>Frame</p>", error: null }] };
    assert.equal(formatPublishedResult(form, payload), payload);
  } else {
    const output = scalars[expectedExport.result.type];
    assert.ok(output, `unsupported result ABI for ${form}`);
    assert.equal(resultKind(form), output.kind);
    assert.equal(formatPublishedResult(form, output.result), output.input);
    if (resultKind(form) !== "string") assert.equal(formatPublishedResult(form, result), input);
  }
  covered.add(type);
}
assert.deepEqual(covered, new Set(Object.keys(scalars)));
for (const unsupported of [undefined, null, {}, "natSvg", "multilineBool", "String"]) {
  assert.throws(() => scalarKind(unsupported), /Unsupported Lean Run form/);
}
console.log(`Native-to-browser wire projection passed for ${forms.length} forms`);
