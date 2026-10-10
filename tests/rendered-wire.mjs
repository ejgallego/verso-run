import assert from "node:assert/strict";
import { scalarKind, resultKind, formatPublishedResult, MAX_FRAMES, MAX_OUTPUT } from "../web/contract.js";

const payload = {version: 1n, frames: [{label: "Start", html: "<p>世界 🌍</p>", error: null}]};
assert.equal(formatPublishedResult("sequence", payload), payload);
const transferred = structuredClone(payload);
assert.deepEqual(transferred, payload);
assert.equal(typeof transferred.version, "bigint");
assert.equal(formatPublishedResult("uint64Sequence", transferred), transferred);
assert.equal(scalarKind("natHtml"), "nat");
assert.equal(scalarKind("boolHtml"), "bool");
assert.equal(resultKind("boolHtml"), "string");
assert.equal(formatPublishedResult("boolHtml", "<p>Enabled</p>"), "<p>Enabled</p>");
assert.throws(() => formatPublishedResult("boolHtml", true), /invalid String/);
for (const form of ["toString", "__proto__", "natSvg", "multilineBool", null, {}]) {
  assert.throws(() => scalarKind(form), /Unsupported Lean Run form/);
  assert.throws(() => resultKind(form), /Unsupported Lean Run form/);
}
for (const invalid of [null, "{}", {version: 1, frames: payload.frames},
    {...payload, version: 2n}, {...payload, frames: []},
    {...payload, frames: Array(MAX_FRAMES+1).fill(payload.frames[0])},
    {...payload, frames: [{label: "Start", html: 7, error: null}]},
    {...payload, frames: [{label: "Start", html: "", error: undefined}]}]) {
  assert.throws(() => formatPublishedResult("sequence", invalid), /invalid sequence/);
}
const limit = {version: 1n, frames: [{label: "", html: "🌍".repeat(MAX_OUTPUT/2), error: null}]};
assert.equal(formatPublishedResult("sequence", limit), limit);
assert.throws(() => formatPublishedResult("sequence", {
  ...limit, frames: [{...limit.frames[0], error: "x"}]}), /exceeds/);
assert.throws(() => formatPublishedResult("sequence", {
  ...limit, frames: [{...limit.frames[0], label: "x"}]}), /exceeds/);
console.log("typed rendering wire, clone, strict forms and UTF-16 budgets passed");

const frame = payload.frames[0];
assert.equal(formatPublishedResult("automaton", frame), frame);
assert.deepEqual(structuredClone(frame), frame);
for (const invalid of [null, "{}", {...frame, error: undefined}, {...frame, html: 0}]) {
  assert.throws(() => formatPublishedResult("automaton", invalid), /invalid sequence frame/);
}
assert.throws(() => formatPublishedResult("automaton", {...frame, html: "x".repeat(MAX_OUTPUT)}), /exceeds/);
