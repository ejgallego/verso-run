import assert from "node:assert/strict";
import { scalarKind, resultKind, formatPublishedResult, MAX_FRAMES, MAX_OUTPUT,
  MAX_VALUE_DEPTH, MAX_VALUE_NODES } from "../web/contract.js";

const text = string => ({kind:"text", fields:{escape:true, string}});
const frame = {label:"Start", content:text("世界 🌍"), error:null};
const sequence = {initial:frame, steps:[]};
for (const [form, value] of [["html",frame.content],["sequence",sequence],["automaton",frame]]) {
  assert.equal(formatPublishedResult(form,value),value);
  assert.deepEqual(structuredClone(value),value);
  assert.throws(() => formatPublishedResult(form,null), /invalid rendered result/);
  assert.throws(() => formatPublishedResult(form,"markup"), /invalid rendered result/);
}
assert.equal(formatPublishedResult("uint64Sequence", sequence), sequence);
assert.equal(scalarKind("natHtml"), "nat");
assert.equal(scalarKind("boolHtml"), "bool");
assert.equal(resultKind("boolHtml"), "html");
for (const form of ["toString", "__proto__", "natSvg", "multilineBool", null, {}]) {
  assert.throws(() => scalarKind(form), /Unsupported Lean Run form/);
  assert.throws(() => resultKind(form), /Unsupported Lean Run form/);
}
assert.throws(() => formatPublishedResult("sequence", {initial:frame, steps:Array(MAX_FRAMES).fill(frame)}), /invalid sequence/);
const limit = {label:"", content:text("🌍".repeat((MAX_OUTPUT-4)/2)), error:null};
assert.equal(formatPublishedResult("automaton",limit),limit);
assert.throws(() => formatPublishedResult("automaton", {...limit, error:"x"}), /exceeds/);
assert.throws(() => formatPublishedResult("automaton", {...limit, label:"x"}), /exceeds/);
// Bounds apply to the complete value, independently of constructor encodings.
assert.throws(() => formatPublishedResult("html", {values:Array(MAX_VALUE_NODES).fill(null)}), /structured-value limit/);
let deep = {};
for (let i=0; i<MAX_VALUE_DEPTH+1; ++i) deep={child:deep};
assert.throws(() => formatPublishedResult("html",deep), /structured-value limit/);
const cyclic = {}; cyclic.child=cyclic;
assert.throws(() => formatPublishedResult("html",cyclic), /structured-value limit/);
assert.throws(() => formatPublishedResult("automaton", {...frame, content:undefined}), /invalid structured value/);
console.log("Typed values survive clone unchanged; scalar policies and transfer budgets passed");
