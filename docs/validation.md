# Validation

The acceptance suite executes the native generators and real Chromium workers.
It compares browser results with native Lean and checks known semantic cases
independently of that agreement.

## Reproduce the gates

Run these sequentially; mutation tests temporarily edit sources and restore them:

```sh
lake build
lake test -- --mutations --output _out/acceptance
```

The suite writes command logs and structured results to the selected ignored
output directory. See [contributing](../CONTRIBUTING.md#build-and-test) for caches,
individual commands and mutation isolation.

CI also builds the [independently pinned author starter](../examples/manual-starter/README.md)
from its complete Git manifest without artifact-cache reuse. That gate qualifies
its published dependency revision; working-tree acceptance qualifies the current
extension sources. CI then packages the three-genre demo and runs its smoke gate.
A main-branch workflow deploys only after these checks pass.

For a local package check:

```sh
python3 scripts/build-demo-site.py
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with playwright python tests/pages-smoke.py \
  --site _out/html-multi --revision "$(git rev-parse HEAD)" \
  --output _out/demo-site-results.json
```

The build must be clean. `verso-run-build.json` records source, dependencies and
runtime; smoke checks verify the publication and execution against the local
native oracle. A hosted run additionally requires that deployed revision. See
[hosting](hosting.md) for deployment and packaging.

## Coverage

- **Interfaces and authoring:** all admitted input/presentation forms, exact
  compiler expectations, metadata rejection, source-located author diagnostics,
  imported and inline entries, checked anchors and unsupported dependencies.
- **Library boundaries:** one Lake owner per source; the standalone `Views` import
  excludes genre adapters, VIR compiler and DOM modules. Ordinary presenter
  imports exclude Verso authoring; its native carrier excludes the DOM
  implementation. A plain Lean fixture publishes without a document or project
  marker, then compares finite/live worker frames with native output at root and
  nested URLs, including UInt64 wraparound and independent sessions.
- **Publication:** complete embedded inventories, resource roles, matching
  runtimes, idempotent bindings, conflicts before writes, native generation
  outside the checkout, relocated carrier roots, and source/helper mutation with
  restored program identity. Runtime identity remains independent of source edits.
- **Execution:** exact scalar values, Unicode and multiline input, independent
  workers, useful failures and explicit recovery, pending-load/import cancellation,
  shared publication acquisition, real interruption of synchronous Wasm, stale
  completion suppression and disposal.
- **Views and lifetimes:** every exercised native sequence frame, selection and
  scrubbing without reevaluation, raw-markup isolation, frame budgets, listener
  cleanup, held loads and paint backpressure. Native Life rules cover still lifes,
  oscillation, extinction, glider movement and dead boundaries. Live playback
  passes the former generation limits without growing the DOM. Drafts, Restart,
  visibility, retired controls, error-session Stop and late loads are exercised.
- **Genres and static output:** Manual's two HTML layouts and TeX; Blog Page/Post
  collection, draft policy and relative paths; Slides asset composition, native
  fragments, hidden submission guards, navigation cancellation and scroll-view
  restoration. Source remains readable without JavaScript.

The library-boundary fixture is `tests/client.py`; its producer imports
`VersoLeanRun.Views` and its worker calls VIR directly. The import gate accounts
for the pinned upstream Html quoter and VIR host-validation imports described in
[internals](internals.md#library-boundaries).

## Qualification limits

Browser execution is qualified in Chromium. Firefox, Safari, physical mobile
devices and assistive-technology audits require separate qualification.
Visibility races use controlled events and suspended paint callbacks around real
iframe loads; they do not qualify operating-system tab throttling. Cached-page
handling uses a synthetic persisted `PageTransitionEvent`; actual browser
back-cache restoration remains unqualified.

Raw Html tests exercise scripts, event handlers, external resources, top
navigation and forms under the shared sandbox policy. They establish the tested
behavior, not a comprehensive HTML-security audit. Only exercised VIR DOM
bindings are covered. Illuminate qualification is limited to drawing-command/SVG
output; broader diagram rendering retains the float-provider gaps recorded in
[its evidence](../evidence/illuminate-gates.md).

Compiler scheduling and native precompilation remain separate work. Keep the
[current pins](internals.md#pinned-dependencies) until a matched source/runtime
update is deliberately qualified.

## Exact results and retained evidence

Use the [CI runs](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml)
and their artifacts for exact source revisions, results, logs and packaged sites.
PR descriptions link review evidence; ignored `_out/` directories hold local
campaigns. A result qualifies its recorded source/runtime pair and configuration.

Earlier generated reports remain in Git history at `23f449e`. The historical
[typed-form claim](../evidence/typed-forms-claim.md) records its bounded campaign;
it is not the current API specification. The [provenance page](history.md)
explains design origins, and [internals](internals.md) describes current contracts.
