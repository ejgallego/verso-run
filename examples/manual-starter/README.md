# A small runnable manual

Copy this directory to start an independent Verso Manual project with two
compiled examples: a `String → String` greeting and a `String → Html` card.
It depends on the published `verso-run` Git revision, with no sibling checkout,
local path dependency, or Illuminate example code.

From a clean `verso-run` checkout, copy the starter and switch to your new project:

```sh
cp -R examples/manual-starter ../my-manual
cd ../my-manual
```

Install [elan](https://github.com/leanprover/elan), then, from this directory:

```sh
lake build
lake exe starter-manual --with-html-single --with-tex --depth 2
python3 -m http.server 8796 --bind 127.0.0.1 --directory _out/html-multi
```

Open <http://127.0.0.1:8796/Greeting/> or
<http://127.0.0.1:8796/HTML-card/>. Change the name and choose Run.
Single-page HTML is in `_out/html-single`; TeX is in `_out/tex`.
Serve the complete HTML directory over HTTP, including `lean-run/` and all
generated assets. Copying it under a nested URL prefix also works.

This starter pins public extension `a830999`, which uses the current `entry` API:
no export attribute is required, and the result type selects text or HTML display.
See [the authoring guide](../../docs/authoring.md).

The toolchain and dependency revision are intentionally pinned. Lake fetches
the matching Verso, VIR, and locked runtime through `verso-run`. Keep these
compatible when updating the dependency.

## The pieces to edit

- `chapters/Starter/Chapter.lean`: the document and runnable declarations.
  `entry` registers scalar callables. Typed HTML entries get an automatic
  scalar adapter named `<entry>.leanRunHtml`.
- `resources/Starter/Resources.lean`: embeds the prepared program from
  `include_vir_assets (modules := #[Starter.Chapter])` in the `StarterResources` library.
- `Main.lean`: registers the embedded bundle with `VersoLeanRun.publish`.
- `lakefile.lean`: keeps chapter compilation ahead of resource preparation,
  embedding, and the native generator. Its resource library `needs` contains the
  module resource facet `` `+Starter.Chapter:virResourcePack ``;
  the generated root interface exposes entries selected by the chapter. The module facet is independent of the carrier library or package name.
- `lake-manifest.json`: locks the extension and its transitive Git dependencies
  to the revisions used to validate this starter.

Add a new runnable function to the chapter; the root interface is generated
from its entry-selected exports, without JSON recipes or role aliases. Supported forms are pure, monomorphic `String → String`, `Nat → Nat`,
`Bool → Bool`, `UInt64 → UInt64`, and `String → Verso.Output.Html`.
Use `+multiline` for a String textarea; Ctrl+Enter or ⌘+Enter runs it. The displayed source is compiled during the
document build; readers change input data. Unsupported types and dependency
closures fail during authoring or resource preparation.

Keep `compiler.postponeCompile false` for now. The chapter imports extension
support; the native generator imports the chapter and its separate resource
carrier. These dependencies must remain acyclic.

The parent repository's `tests/starter.py` copies this directory to an isolated
project, builds without Lake artifact-cache reuse from the exact public Git revision, and checks the real worker in Chromium at both root
and nested URLs, including escaped HTML, no-JavaScript source, and TeX output.

The starter is provided under the Apache-2.0 license in [LICENSE](LICENSE).
