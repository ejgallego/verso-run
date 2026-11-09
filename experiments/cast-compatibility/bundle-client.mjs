// Run the exact upstream regressions against the consumer's native editor host.
// Infoview transport and the shell are controlled; React and Cast are real.
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";

const [project, host, helper, output] = process.argv.slice(2).map(path => resolve(path));
const require = createRequire(resolve(project, ".lake/packages/lean_vir/package.json"));
const { build } = require("esbuild");
const source = resolve(project, "cast-source");
const manifest = JSON.parse(await readFile(resolve(source, "package.json"), "utf8"));
if (typeof manifest.exports["./preview"] !== "string") throw Error("Missing public preview export");
await mkdir(output, { recursive: true });
const result = await build({
  absWorkingDir: project, entryPoints: [resolve(source, "tests/preview-client.browser.mjs")],
  outfile: resolve(output, "app.js"), bundle: true, format: "esm", metafile: true,
  nodePaths: [resolve(project, ".lake/packages/lean_vir/node_modules")],
  plugins: [{ name: "consumer-editor-peer", setup(build) {
    // Both the public export and upstream regression use the same helper.
    build.onResolve({ filter: /^(verso-cast\/preview|\.\.\/js\/preview\.mjs)$/ }, () => ({ path: helper }));
    build.onResolve({ filter: /^@leanprover\/infoview$/ }, () =>
      ({ path: resolve(source, "tests/reference-manual/infoview-peer.mjs") }));
    build.onResolve({ filter: /^\.\/widget\.mjs$/ }, () => ({ path: "consumer-host", namespace: "peer" }));
    build.onResolve({ filter: /^__VIR_SHELL__$/ }, () => ({ path: "shell", namespace: "peer" }));
    build.onLoad({ filter: /.*/, namespace: "peer" }, args => ({
      contents: args.path === "shell" ? "export default function Shell() {}" :
        `export { PageHost as ReferencePage } from ${JSON.stringify(host)};`,
      resolveDir: project,
    }));
  } }],
});
await writeFile(resolve(output, "bundle.json"), JSON.stringify(result.metafile, null, 2) + "\n");
await writeFile(resolve(output, "index.html"),
  '<link rel="icon" href="data:,"><div id="app"></div><script type="module" src="app.js"></script>');
