# Next slices

The project has a copyable Manual starter and a GitHub Pages deployment workflow.
Keep exact dependencies and the current execution boundary.

## Selected public runtime integration

The selected pair is public VIR PR #217 commit `bda79d5c` and runtime `e415…`
(pack SHA256 `3910c29e…`). Source acquisition and exact public bytes are verified.
The consumer migration uses typed owner/module registration, full Lean declaration
names, independent `{args, result, effect}` expectations, and exact BigInt Nat
results. Publication and runtime admission retain their separate phases.

Consumer acceptance passed: 79 native/browser/mutation checks, 11 cold Git-only
starter checks without Lake artifact-cache reuse, and actual Pages/native
agreement for Greeting, exact Nat, escaped HTML, and Illuminate SVG. Runtime
JavaScript was served as `application/javascript` on Pages. Evidence is linked
from [validation](docs/validation.md).

The VIR Module owner retains final-head producer CI and any upstream merge
decision; neither native precompilation nor alternative embedding APIs are
selected by this migration. Future producer updates still require matched public
source/runtime qualification.

## Unsupported-program diagnostics

The diagnostics slice preserves VIR classifier reasons, distinguishes VIR
rejection from form restrictions, and gives declaration/type context and next
steps. Its fixtures cover effects, arity, polymorphism, implicit parameters,
dependent results, and non-executable entries. Mutation checks exercise rejected
rebuilds and bad recipe contracts after successful publication.

Distinguish author-program rejection from invalid reader inputs and worker
failures. Readers currently edit scalar inputs, not Lean source; source editing
belongs to the future editor work. Retain plain-text runtime errors, preview
cleanup, explicit retry, and real Stop.

Further dependency-closure diagnostics and future runtime/schema behavior should
be reviewed with the VIR owner. See
[troubleshooting](docs/troubleshooting.md) and [validation](docs/validation.md).

## Verso anchors and multiple genres

The [source review and adapter plan](docs/multi-genre.md) identifies the shared
Verso anchor loader and `ExternalCode` interface; Manual and Blog already supply
instances. Source anchors, executable declarations, document links, and form
instances have separate identities.

The common model, classifier, console, AST collector, and publication planner
are extracted behind the existing Manual API. `leanRunAnchor` reuses checked
Verso anchors with an explicit imported scalar entry and a producer-owned bundle.
The demo includes ordinary and runnable displays of the same source region.

Next add a Blog adapter covering Page and Post. Select a compatible Slides
revision before implementing its source, asset, and Reveal lifecycle adapter.
Preserve each genre's native highlighted blocks, links, styling, and static
fallback. Qualify an independent example in each genre before claiming support
beyond Manual. Keep the public VIR integration gate separate.

## Later Verso upstreaming slice

Group Verso core work for later review: the public highlighting hook and any
shared hooks required by the anchors/genre work. Discuss compiler scheduling
with the compiler maintainer before changing `compiler.postponeCompile false`.
Native precompilation remains deferred pending the separate VIR fix.

## Deferred qualification

General Illuminate diagrams require the recorded VIR float-provider work in
`evidence/illuminate-gates.md`. Wider browser and accessibility qualification
remain later work. Editor support and the more ambitious `verso-lab` project
are separate from this compiled Run extension.
