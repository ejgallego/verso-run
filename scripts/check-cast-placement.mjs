import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { root, selectedPackage } from "./selected-package.mjs";
import { mathPlugin } from "./cast-math.mjs";
const vir = await selectedPackage("lean_vir");
const cast = await selectedPackage("verso-cast");
const require = createRequire(resolve(vir, "package.json"));
const { build } = require("esbuild");
const peer = resolve(cast, "tests/reference-manual/infoview-peer.mjs");
const math = process.argv.includes("--math");
const output = resolve(root, math ? "_out/cast-math" : "_out/cast-placement");
const manifest = JSON.parse(await readFile(resolve(vir, "package.json"), "utf8"));
const runtimeExports = Object.fromEntries([".", "./host-bindings", "./react-host-bindings"].map(key =>
  [key === "." ? "lean-vir" : "lean-vir/" + key.slice(2), resolve(vir, manifest.exports[key])]));
await mkdir(output, { recursive: true });
await build({ absWorkingDir: root, entryPoints: [math ? "tests/cast-math.browser.mjs" : "tests/cast-placement.browser.mjs"],
  outfile: resolve(output, "app.js"), bundle: true, format: "esm", loader: { ".css": "text" },
  define: { __RUN_RUNTIME_CONTENT_ID__: JSON.stringify("1".repeat(64)) },
  nodePaths: [resolve(vir, "node_modules")], plugins: [await mathPlugin(build, cast), { name: "controlled-editor", setup(build) {
    build.onResolve({ filter: /^(@leanprover\/infoview|@cast-test\/infoview-peer)$/ }, () => ({ path: peer }));
    build.onResolve({ filter: /^lean-vir(?:\/(?:host-bindings|react-host-bindings))?$/ }, args => ({ path: runtimeExports[args.path] }));
    build.onResolve({ filter: /^__VIR_SHELL__$/ }, () => ({ path: resolve(root, math ? "tests/cast-math-shell.mjs" : "tests/cast-placement-shell.mjs") }));
    build.onResolve({ filter: /^__RUN_WORKER__$/ }, () => ({ path: "worker", namespace: "fixture" }));
    build.onLoad({ filter: /.*/, namespace: "fixture" }, () => ({ contents: 'export default "controlled worker"' }));
  } }] });
await writeFile(resolve(output, "index.html"), '<link rel="icon" href="data:,"><div id="app"></div><script type="module" src="app.js"></script>');
