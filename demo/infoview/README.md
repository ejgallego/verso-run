# Manual Run preview

This optional demo shows Manual prose, highlighted inline and anchored Lean
source, and scalar Run controls in the Lean infoview. Each placement owns its
worker. Editing the page stops execution; after checking finishes, choose Run to
execute the new code.

Inline and display math use Cast's public KaTeX component, configured by the
Lean renderer. KaTeX and its fonts come from the pinned Verso assets and are
bundled into the widget; the preview needs no remote font server. Invalid TeX
remains visible.

For example, add these lines inside the document:

```lean
Inline: $`a + x \alpha`

Display: $$`\frac{a}{b}`
```

The demo is under active qualification in [PR #23](https://github.com/ejgallego/verso-run/pull/23).
The native browser lifetime checks and actual rc2/Wasm scalar calls pass.
In the earlier VS Code baseline, the panel rendered source and ran scalar
examples in independent workers. Its blob worker and Stop path were exercised
in the infoview.
Interactive assertions also observed unsaved execution and error refusal, but
the complete edit/recovery and same-version restart gates remain open. This
prototype stays a draft.
HTML, sequence, automaton and custom-result presentation are not connected to
the editor backend yet. Their site implementation keeps the existing behavior.

Cast's Lean component owns page requests, retained prose, status and Debug UI.
The native editor host supplies a selected page's session and abort signal. Each
Run placement receives that exact captured signal and owns its worker cleanup,
so edits and unmount can stop execution even when the Lean view is unavailable.
The current Lean-first integration still needs a fresh VS Code acceptance run.

## Checking latency

Asset preparation writes a small runtime manifest for the document and resolves
the registered VIR shell in the widget bundle. Document checking reads those
prepared values instead of reconstructing the Wasm payload or rewriting the
bundled JavaScript on every edit.

On the local rc2 demo, the same frozen file took 5.03 seconds before this change
and 2.52 seconds afterward in warm, instrumented frontend runs. A separate
six-run comparison isolated the runtime-manifest change: median time fell from
3.53 to 2.47 seconds with the same imports and widget. These measurements include
`lake env lean` startup; they do not measure VS Code edit-to-preview latency.

The imported anchor still asks Verso to check its external source through two
nested Lake commands. That took 1.34–1.83 seconds in these profiles, even with
warm outputs. The current consumer preserves those dependency checks. The
highlighted-source target already depends on the extractor, so eliminating the
separate extractor command is a candidate improvement in Verso.

## Prepare and open

Run these commands in the task worktree with Lean 4.36.0-rc2, Git, Node/npm,
and VS Code with the Lean extension and `code` command installed. This local
qualification uses the matched VIR API `46fd2952` / lock `dbc70357` kit and
Cast's frozen Lean-first source snapshot `a9d4b3c9`. Public dependency pins remain
unchanged; portable public acquisition is still a landing gate.

Fetch the pinned dependencies with `lake update` in a fresh worktree, then run:

```sh
python3 scripts/setup-cast-demo.py --editor-fixture \
  --runtime-kit /path/to/cast-native-leaves-kit-46fd2952-20261111 \
  --cast-source-kit /path/to/source-handoff/a9d4b3c955abff7be6b0286e1c5e24bae16fc7a9d2a7c19cba23627c12ac7a96
bash _out/cast-demo/open-vscode.sh
```

The clean `tests/cast/CastEditorFixture.lean` contains inline and anchored calls,
independent placements, a long-running Stop example and inline/display math.
Omit `--editor-fixture` to select `demo/infoview/LeanRunInfoview/Demo.lean` instead.
Setup preserves existing edits to either file. It enables
`lean4.infoview.autoOpen` in `.vscode/settings.json`; an existing settings file
must use plain JSON.

Setup verifies the kit's source, SDK and runtime hashes, uses VIR's ordinary
native preparation, and builds the widget and its bundled worker. Independent
source directories under `_out/cast-demo/` are selected through Lake's supported
`.lake/package-overrides.json`. No SDK, runtime or dependency build outputs are
copied from another worktree. Setup can replace its own clean prior selection;
it refuses foreign overrides and preserves unrelated entries.

The generated launcher selects the exact SDK archive and starts an isolated
VS Code user-data directory. This prevents an already running editor from
silently retaining a different SDK environment. Use that launcher for this
local checkpoint.

Open the Lean infoview after the page finishes checking. Run the greeting and
anchored doubling examples; the expected results are `Hello, Ada!` and `42`.
The second greeting placement starts with `Grace` and keeps its own input.
Change an input, then choose Run again. Run the counter with its large initial
input and choose Stop while it computes; the greeting controls remain usable.
Change the greeting's body without rebuilding the website: old execution must
stop immediately, and the next explicit Run must use the newly checked body.

The generated `.vir/` assets, `.vir-generated/` widget, build outputs and local
runtime selection stay outside Git. This local preparation does not publish a
runtime or make the public lock usable. Public dependency adoption remains a
landing gate. Setup without local-source flags uses the selected dependencies normally once their public inputs are usable.

## Qualification commands

Run checks in a shell with the same SDK selected by setup:

```sh
export VIR_SDK_ARCHIVE=/path/to/cast-native-leaves-kit-46fd2952-20261111/SDK/lean-vir-sdk.tar.gz
export VIR_SDK_EXPECT_COMMIT=46fd2952b3a1dc05772f637b5f2f9c69d3e0bc9f
unset VIR_SDK_URL VIR_SDK_TAG VIR_SDK_COMMIT VIR_SDK_REPO
lake build
lake test -- --mutations
```

Run the build and mutation suite sequentially; mutation checks edit and restore
source files.

The rc2 build and all 101 mutation-suite checks pass with the disclosed local
selections. The editor acceptance limits above remain separate.

The focused source and native-browser checks are:

```sh
lake build +CastSourceGate:olean
lake env lean tests/CastSources.lean
lake env lean tests/CastPackages.lean
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with playwright python tests/cast-placement.py
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with playwright python tests/cast-math.py
```

The math check runs the actual compiled Lean adapter and real Manual math nodes
against a controlled editor transport. It checks inline/display math, malformed
TeX, source preservation and embedded fonts. Its screenshot and result are under
`_out/cast-math/`; actual VS Code math/CSP acceptance remains separate.

`tests/CastRuntime.lean` and `tests/cast-byte-program.mjs` additionally inspect an
explicit source-paired pack and execute the real producer packages through the
public byte loader. These checks cover actual Wasm calls, independently admitted
contracts and disposal, rather than real editor behavior. See the
[design and evidence scope](../../docs/cast-infoview-design.md).
