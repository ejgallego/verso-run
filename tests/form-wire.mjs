import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { scalarKind, decodeInput, formatResult } from "../web/contract.js";

// Input comes from Lean's ToJson instances and canonical VIR expectations, rather
// than a second handwritten list of form tags that could drift with the browser.
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
  assert.equal(expectedExport.result.type, type);
  assert.ok(Object.hasOwn(scalars, type), `unsupported scalar ABI: ${type}`);
  const { kind, input, decoded, result } = scalars[type];
  assert.equal(scalarKind(form), kind, `wire projection for ${form}`);
  assert.equal(decodeInput(scalarKind(form), input), decoded);
  assert.equal(formatResult(scalarKind(form), result), input);
  covered.add(type);
}
assert.deepEqual(covered, new Set(Object.keys(scalars)));
for (const unsupported of [undefined, null, {}, "natHtml", "multilineBool", "String"]) {
  assert.throws(() => scalarKind(unsupported), /Unsupported Lean Run form/);
}
console.log(`Native-to-browser wire projection passed for ${forms.length} forms`);
