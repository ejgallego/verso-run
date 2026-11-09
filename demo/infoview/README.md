# Manual Run preview

This optional demo shows Manual prose, highlighted inline and anchored Lean
source, and scalar Run controls in the Lean infoview. Each placement owns its
worker. Editing the page stops execution; after checking finishes, choose Run to
execute the new code.

The demo is under active qualification in [PR #23](https://github.com/ejgallego/verso-run/pull/23).
The native browser lifetime checks and actual rc2/Wasm scalar calls pass.
The real VS Code panel renders source and runs scalar examples in independent
workers. Its blob worker and Stop path have been exercised in the infoview.
Interactive assertions also observed unsaved execution and error refusal, but
the complete edit/recovery and same-version restart gates remain open. This
prototype stays a draft.
HTML, sequence, automaton and custom-result presentation are not connected to
the editor backend yet. Their site implementation keeps the existing behavior.

## Prepare and open

Run these commands in the task worktree. It requires the selected Lean rc2
compiler and the exact source-paired local runtime kits supplied by the VIR
runtime owner. Keep the lock-checkpoint kit beside its matched artifact kit.
Public acquisition at the current VIR pin is unavailable. Cast's flat source
decoder correction is also selected through its owner's frozen source kit while
its signed commit is pending; the public dependency pin remains unchanged.

```sh
lake update
python3 scripts/setup-cast-demo.py \
  --runtime-kit /path/to/versorun-rc2-lock-3d01e517-20261109 \
  --cast-source-kit /path/to/cast-source-handoff/61292bad52a03611058aa22fa126c6cac9d866fb045e920ef3d3612828077765
code --new-window . --goto demo/infoview/LeanRunInfoview/Demo.lean:13
```

Setup checks the lock checkpoint kit against the pinned VIR source, verifies the runtime pack
through VIR's native acquisition tool, and prepares the widget and its bundled
worker. It creates a private source clone under `_out/cast-demo/` at the immutable
local checkpoint. Only that checkpoint's relative runtime lock differs from the
pinned API source. Lake's normal
`.lake/package-overrides.json` selects it for builds, nested tests and the editor.
The Cast source archive is independently hash-checked and extracted into a
separate local source directory selected through the same override mechanism.
Other dependency checkouts and worktrees retain their own outputs.
Setup refuses a different existing override for either dependency and preserves
unrelated overrides and edits to its source copies.

Open the Lean infoview after the page finishes checking. Run the greeting and
anchored doubling examples; the expected results are `Hello, Ada!` and `42`.
The second greeting placement starts with `Grace` and keeps its own input.
Change an input, then choose Run again. Run the counter with its large initial
input and choose Stop while it computes; the greeting controls remain usable.
Change the greeting's body without rebuilding the website: old execution must
stop immediately, and the next explicit Run must use the newly checked body.

The generated `.vir/` assets, `.vir-generated/` widget, build outputs and local
runtime selection stay outside Git. This local preparation does not publish a
runtime or make the public lock usable. Public dependency adoption remains a landing gate. Setup without local-source
flags uses the selected dependencies normally once their public inputs are usable.

## Qualification commands

Run the standard checks sequentially, after setup:

```sh
lake build
lake test -- --mutations
```

The rc2 build and all 101 mutation-suite checks pass with the disclosed local
selections. The editor acceptance limits above remain separate.

The focused source and native-browser checks are:

```sh
lake build +CastSourceGate:olean
lake env lean tests/CastSources.lean
lake env lean tests/CastPackages.lean
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with playwright python tests/cast-placement.py
```

`tests/CastRuntime.lean` and `tests/cast-byte-program.mjs` additionally inspect an
explicit source-paired pack and execute the real producer packages through the
public byte loader. These checks cover actual Wasm calls, independently admitted
contracts and disposal, rather than real editor behavior. See the
[design and evidence scope](../../docs/cast-infoview-design.md).
