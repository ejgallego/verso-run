import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { root, selectedPackage } from "./selected-package.mjs";
const vir = await selectedPackage("lean_vir");
const cast = await selectedPackage("verso-cast");
const require = createRequire(resolve(vir, "package.json"));
const { build } = require("esbuild");
const peer = resolve(cast, "tests/reference-manual/infoview-peer.mjs");
const output = resolve(root, "_out/cast-placement");
await mkdir(output, { recursive: true });
await build({ absWorkingDir: root, entryPoints: ["tests/cast-placement.browser.mjs"],
  outfile: resolve(output, "app.js"), bundle: true, format: "esm", loader: { ".css": "text" },
  define: { __RUN_RUNTIME_CONTENT_ID__: JSON.stringify("1".repeat(64)) },
  nodePaths: [resolve(vir, "node_modules")], plugins: [{ name: "controlled-editor", setup(build) {
    build.onResolve({ filter: /^(@leanprover\/infoview|@cast-test\/infoview-peer)$/ }, () => ({ path: peer }));
    build.onResolve({ filter: /^verso-cast\/preview$/ }, () => ({ path: resolve(cast, "js/preview.mjs") }));
    build.onResolve({ filter: /^__VIR_SHELL__$/ }, () => ({ path: resolve(root, "tests/cast-placement-shell.mjs") }));
    build.onResolve({ filter: /^__RUN_WORKER__$/ }, () => ({ path: "worker", namespace: "fixture" }));
    build.onLoad({ filter: /.*/, namespace: "fixture" }, () => ({ contents: 'export default "controlled worker"' }));
  } }] });
await writeFile(resolve(output, "index.html"), '<link rel="icon" href="data:,"><div id="app"></div><script type="module" src="app.js"></script>');
