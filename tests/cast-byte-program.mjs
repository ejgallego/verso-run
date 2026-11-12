// Actual rc2/Wasm calls from the two real authoring paths. Inputs come from an
// existing source-paired bundle; this is not a default runtime-acquisition test.
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { selectedPackage } from "../scripts/selected-package.mjs";
const root = resolve(new URL("..", import.meta.url).pathname);
const [directory, expectedContentId, expectedSource] = process.argv.slice(2);
assert(directory && /^[0-9a-f]{64}$/.test(expectedContentId ?? "") && /^[0-9a-f]{40}$/.test(expectedSource ?? ""),
  "usage: cast-byte-program RUNTIME_DIRECTORY EXPECTED_CONTENT_ID EXPECTED_VIR_REVISION");
const vir = await selectedPackage("lean_vir");
const git = args => execFileSync("git", args, { cwd: vir, encoding: "utf8" }).trim();
const checkoutRevision = git(["rev-parse", "HEAD"]);
if (checkoutRevision !== expectedSource) {
  assert.equal(git(["rev-parse", "HEAD^"]), expectedSource);
  assert.equal(git(["diff", "--name-only", expectedSource, "HEAD"]), "vir-resources/runtime.json");
}
const sdk = resolve(vir, ".lake/build/vir/sdk");
const metadata = JSON.parse(await readFile(resolve(sdk, "lean-vir-artifact.json"), "utf8"));
assert.equal(metadata.gitCommit, expectedSource);
assert.equal(metadata.gitDirty, false);
const { createVirRuntimeFactory } = await import(pathToFileURL(resolve(sdk, "js/vir-runtime-node.js")));
const runtimeManifest = JSON.parse(await readFile(resolve(directory, "envelope.json"), "utf8"));
assert.equal(runtimeManifest.contentId, expectedContentId);
const factory = createVirRuntimeFactory({ wasmBytes: new Uint8Array(await readFile(resolve(directory, "runtime.wasm"))),
  runtimeManifest, expectedRuntimeContentId: expectedContentId });
const contracts = JSON.parse(await readFile(resolve(root, "_out/rc2-demo/source-contracts.json"), "utf8"));
const programs = [];
try {
  for (const [index, file] of ["inline", "anchor"].entries()) {
    const row = contracts[index];
    const bytes = new Uint8Array(await readFile(resolve(root, `_out/rc2-demo/${file}.irpkg`)));
    const expected = structuredClone(row.expectedExport);
    const pending = factory.createProgram({ irPackageSet: [bytes],
      expectedExports: { [row.description.callable]: expected } });
    // Exercise the real snapshot boundary, not a modeled installer.
    bytes.fill(0);
    expected.result = {native:{type:{tag:"bool"}},value:{tag:"boolean"}};
    const program = await pending;
    programs.push(program);
    const input = file === "inline" ? "Ada" : 21n;
    const value = program.call(row.description.callable, input);
    assert.equal(value, file === "inline" ? "Hello, Ada" : 42n);
    console.log("PASS actual rc2 byte program", file, String(value));
  }
  programs[0].dispose();
  programs[0].dispose();
  assert.equal(programs[0].status, "disposed");
  assert.throws(() => programs[0].call(contracts[0].description.callable, "Ada"), /disposed/);
  assert.equal(programs[1].call(contracts[1].description.callable, 9n), 18n);
  const result = { virRevision: metadata.gitCommit, checkoutRevision, runtimeContentId: expectedContentId,
    leanRevision: runtimeManifest.descriptor.compatibility.leanRevision,
    checks: ["actual leanRun call", "actual leanRunAnchor call", "pre-await input snapshots",
      "independent program disposal", "post-disposal refusal"], actualEditorObserved: false };
  await writeFile(resolve(root, "_out/rc2-demo/byte-program.json"), JSON.stringify(result, null, 2) + "\n");
} finally { for (const program of programs) program.dispose(); }
