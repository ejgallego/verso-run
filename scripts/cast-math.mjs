import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { selectedPackage } from "./selected-package.mjs";

// Reuse Cast's public leaf and the KaTeX assets already pinned by Verso.
// Embedded fonts keep the infoview independent of HTTP servers or a CDN.
export async function mathPlugin(build, cast) {
  const verso = await selectedPackage("verso");
  const directory = resolve(verso, "vendored-js/katex");
  const manifest = JSON.parse(await readFile(resolve(cast, "package.json"), "utf8"));
  const css = await build({ entryPoints: [resolve(directory, "katex.min.css")],
    bundle: true, write: false, minify: true,
    loader: { ".woff2": "dataurl", ".woff": "dataurl", ".ttf": "dataurl" } });
  return { name: "cast-math", setup(builder) {
    builder.onResolve({ filter: /^verso-cast\/katex$/ }, () =>
      ({ path: resolve(cast, manifest.exports["./katex"]) }));
    builder.onResolve({ filter: /^__KATEX__$/ }, () =>
      ({ path: resolve(directory, "katex.min.js") }));
    builder.onResolve({ filter: /^__KATEX_CSS__$/ }, () =>
      ({ path: "katex-css", namespace: "math" }));
    builder.onLoad({ filter: /.*/, namespace: "math" }, () =>
      ({ contents: `export default ${JSON.stringify(css.outputFiles[0].text)};` }));
  } };
}
