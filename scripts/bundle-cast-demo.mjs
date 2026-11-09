// Build only from this worktree's selected dependency sources and locked tools.
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { root, selectedPackage } from "./selected-package.mjs";
const vir = process.argv[2] ? resolve(process.argv[2]) : await selectedPackage("lean_vir");
const require = createRequire(resolve(vir, "package.json"));
const { build } = require("esbuild");
const cast = await selectedPackage("verso-cast");
const [virManifest, castManifest] = await Promise.all([vir, cast].map(async path =>
  JSON.parse(await readFile(resolve(path, "package.json"), "utf8"))));
const runtime = JSON.parse(await readFile(resolve(root, ".vir/infoview-runtime.json"), "utf8"));
if (!/^[0-9a-f]{64}$/.test(runtime.contentId)) throw Error("Prepare the selected runtime before bundling");
const aliases = { "lean-vir": resolve(vir, virManifest.exports["."]),
  "verso-cast/preview": resolve(cast, castManifest.exports["./preview"]) };
const selected = { name: "selected-public-exports", setup(build) {
  build.onResolve({ filter: /^(lean-vir|verso-cast\/preview)$/ }, args => ({ path: aliases[args.path] }));
} };
const worker = await build({ absWorkingDir: root, entryPoints: ["web/cast/worker.js"],
  bundle: true, format: "esm", platform: "browser", write: false, plugins: [selected] });
const widget = await build({ absWorkingDir: root, entryPoints: ["web/cast/widget.js"],
  bundle: true, format: "esm", platform: "browser", write: false,
  external: ["react", "@leanprover/infoview", "__VIR_SHELL__"],
  loader: { ".css": "text" },
  define: { __RUN_RUNTIME_CONTENT_ID__: JSON.stringify(runtime.contentId) },
  plugins: [selected, { name: "worker-source", setup(build) {
    build.onResolve({ filter: /^__RUN_WORKER__$/ }, () => ({ path: "worker", namespace: "inline" }));
    build.onLoad({ filter: /.*/, namespace: "inline" }, () => ({
      contents: `export default ${JSON.stringify(worker.outputFiles[0].text)};` }));
  } }] });
await mkdir(resolve(root, ".vir-generated"), { recursive: true });
await writeFile(resolve(root, ".vir-generated/CastWidget.mjs"), widget.outputFiles[0].contents);
console.log("Prepared native Cast widget and independent worker");
