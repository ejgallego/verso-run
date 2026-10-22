# A small runnable manual

Copy this directory to start an independent Verso Manual project. It includes
two compiled examples: a `String → String` greeting and a `String → Html` card.
The project uses a published `verso-run` Git revision and has no sibling checkout,
local path dependency, or Illuminate example code.

From a clean `verso-run` checkout, copy the starter and enter the new project:

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
<http://127.0.0.1:8796/HTML-card/>, change the name, and choose Run. The build
also creates single-page HTML in `_out/html-single` and TeX in `_out/tex`.
Serve the complete HTML directory over HTTP, including `lean-run/` and all
generated assets. The site also works when copied under a nested URL prefix.

This starter pins public extension revision `f2a1491`. In that revision,
`entry` selects a function without an export attribute, and its result type
selects text or HTML display. See [the authoring guide](https://github.com/ejgallego/verso-run/blob/f2a1491257b8ad0c71b0468abf909c6dcfda9459/docs/authoring.md).

The toolchain and dependency revision are pinned. Lake fetches the matching
Verso, VIR, and locked runtime through `verso-run`. Keep these revisions
compatible when updating the dependency.

## The pieces to edit

- `chapters/Starter/Chapter.lean`: the document and runnable declarations.
  `entry` registers scalar callables. For an HTML result, the build generates a
  `String → String` adapter named `<entry>.leanRunHtml` that serializes the `Html`
  value for the browser preview.
- `resources/Starter/Resources.lean`: embeds the complete runtime and program
  `ResourceSet` returned by `include_vir_assets (modules := #[Starter.Chapter])`
  in the `StarterResources` library.
- `Main.lean`: passes that embedded set to `VersoLeanRun.publish`.
- `lakefile.lean`: orders the build so the chapter compiles before resource
  preparation, embedding, and the native generator. The resource library lists
  `` `+Starter.Chapter:virResourcePack `` in `needs`. This module facet does not
  depend on the carrier library or package name.
- `lake-manifest.json`: locks the extension and its transitive Git dependencies
  to the revisions used to validate this starter.

Add a function to the chapter and select it with `entry`. The build includes
the selected callable and its dependencies in the chapter's program bundle.
Supported forms are pure, monomorphic `String → String`, `Nat → Nat`,
`Bool → Bool`, `UInt64 → UInt64`, and `String → Verso.Output.Html`.
Use `+multiline` to give String inputs a textarea; Ctrl+Enter or ⌘+Enter runs
the function. The document build compiles the displayed source, while readers
change its input. Unsupported types and unavailable runtime operations are
reported during authoring or resource preparation.

Keep `compiler.postponeCompile false`; native precompilation is not qualified.
The chapter imports extension support, while the native generator imports the
chapter and its separate resource carrier. Keep these dependencies acyclic.

The parent repository's `tests/starter.py` copies this directory to an isolated
project and builds it from the pinned public Git revision without reusing Lake
artifacts. Its 11 checks run the real worker in Chromium at root and nested URLs
and cover escaped HTML, source without JavaScript, and TeX output.

The starter is provided under the Apache-2.0 license in [LICENSE](LICENSE).
