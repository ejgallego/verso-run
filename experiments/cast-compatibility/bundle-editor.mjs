// Bundle the exact public Cast export using this consumer's locked VIR tools.
import { readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";

const project = resolve(process.argv[2]);
const require = createRequire(resolve(project, ".lake/packages/lean_vir/package.json"));
const { build } = require("esbuild");
const source = resolve(project, "cast-source");
const manifest = JSON.parse(await readFile(resolve(source, "package.json"), "utf8"));
const publicExport = manifest.exports["./preview"];
if (typeof publicExport !== "string" || !publicExport.startsWith("./js/"))
  throw Error("Expected an explicit public verso-cast/preview export");
const result = await build({
  absWorkingDir: project, entryPoints: ["EditorHost.mjs"], bundle: true, format: "esm",
  outfile: "EditorHostBundle.mjs", metafile: true,
  external: ["react", "@leanprover/infoview", "__VIR_SHELL__"],
  plugins: [{ name: "cast-public-export", setup(build) {
    build.onResolve({ filter: /^verso-cast\/preview$/ }, () => ({ path: resolve(source, publicExport) }));
  } }],
});
await writeFile(resolve(project, "editor-bundle.json"), JSON.stringify({
  publicExport, esbuildVersion: require("esbuild/package.json").version,
  ...result.metafile,
}, null, 2) + "\n");
