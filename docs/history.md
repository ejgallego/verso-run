# Project history

The initial runnable-Manual prototype lived in `experiments/lean-run` on Verso's
local `feat/lean-run` branch. Its eight development commits were extracted from
Verso commit `06860e5e`. Earlier generated reports and captures remain in Git
history at `23f449e`; they describe their recorded revisions.

The project was initially published as `verso-vir`, briefly named `verso-lab`,
and renamed to `verso-run`. The public `VersoLeanRun` module and executable names
were retained. `verso-lab` is reserved for future source-editor work.

## Shared machinery and genre support

The original Manual integration was separated into a callable classifier,
portable experiment model, native-source adapters, console renderer, typed AST
collector, and pure publication planner. Checked anchors reuse Verso's
`ExternalCode` path rather than recovering declarations from rendered HTML.
Imported entries and typed HTML use document-owned scalar adapters.

Blog Page/Post and Slides then adopted the shared callable and publication
machinery while retaining their own source renderers. Inline definitions keep
command scopes across Run blocks. Bool, UInt64, and multiline String controls
share the host/worker codec and cancellation behavior across genres. Selecting
`entry` now registers the export; authors do not need an export annotation or
an `output` option.

## VIR resource and signature integration

VIR supplies the compiler-derived expected-signature encoder and validates
actual callable interfaces during program creation. Earlier encoder and typed
form campaigns are recorded in the historical
[consumer claim](../evidence/typed-forms-claim.md). The older `e415…` runtime was
also qualified on Pages, including its JavaScript MIME handling; those hosted
results do not qualify a later runtime automatically.

The layout migration adopted [VIR PR #229](https://github.com/ejgallego/lean-vir/pull/229):
explicit module resource facets and `include_vir_assets` replaced implicit
carrier-library program selection. Its Lean 4.35.0-rc4 requirement needed two
upstream compatibility adjustments on the existing Verso highlighting fork and
a Slides revision using the same module-owned-assets interface. The independent
starter was cold-qualified against published extension `a830999`.
See [internals](internals.md#pinned-dependencies) for the current exact pins,
and [validation](validation.md) for qualification scope and limits.

## Current layout

Library code lives under `src/`, browser assets under `web/`, and demo chapters,
resource carriers, and generators under `demo/`. Native references and acceptance
fixtures live under `tests/`. Illuminate examples remain outside the library.
The package is named `verso_run`; `VersoLeanRun` and `VersoLeanRun.Publish` remain
the public Manual imports. Generated reports, screenshots, and site files belong
in ignored output directories or CI artifacts; documentation artwork lives in
`docs/images/`.

See [LICENSE](../LICENSE) for the Apache-2.0 license and [CONTRIBUTING](../CONTRIBUTING.md)
for the build, validation, and review workflow.
