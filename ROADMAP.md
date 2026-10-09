# Next slices

The project has a copyable Manual starter and a GitHub Pages deployment workflow.
Keep exact dependencies and the current execution boundary.

## Selected public runtime integration

The selected pair is landed public VIR commit `fb5af647` and runtime `e415…`
(pack SHA256 `3910c29e…`). Source acquisition and exact public bytes are verified.
The consumer migration uses bare Module needs and fixed resource prerequisites, full Lean declaration
names, independent `{args, result, effect}` expectations, and exact BigInt Nat
results. Publication and runtime admission retain their separate phases.

The historical bda/e415 consumer acceptance passed: 79 native/browser/mutation checks, 11 cold Git-only
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
rebuilds and bad producer/compiler contracts after successful publication.

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
Verso anchors with an explicit imported entry and a document-owned callable bundle.
The demo includes ordinary and runnable displays of the same source region.

Blog covers Page and Post with native highlighted source, typed site collection,
shared resource publication, and explicit renderer URLs for nested posts.
Slides uses the compatible public `35b5d14b` snapshot, native fragmentized
source, a shared formatter/Run runtime inventory, and the stock asset planner.
Slide/fragment hiding cancels workers and pending loads; input keys stay with
the form. Native source remains readable without JavaScript.
The landing links to executable examples in all three genres.

Preserve each genre's native links, styling, source, and lifecycle. Future Slides
updates require deliberate dependency selection and qualification. The owner
retains upstream landing decisions for its review snapshot.

## Concrete typed Run forms

The selected consumer slice adds Bool/UInt64 and multiline String controls to
Manual, Blog, and Slides with the shared codec and worker lifecycle. Forms remain
bounded, pure, monomorphic, and homogeneous; multiline is presentation only.
The independently classified expectation stays an ordered `args` array of canonical
type descriptors, one `result` descriptor, and the canonical `effect` label.
Parameter names and UI metadata are outside that expectation.

The native owner supplies the matching pure expected-signature encoder. Agreement
is retained in [the consumer claim](evidence/typed-forms-claim.md). The selected public adoption uses the compiler-owned
`callSignature.toExpectedSignatureJson` encoder on source `fb5af647`, with the
same e415 runtime. The earlier local adoption remains historical evidence: Explicitly selected source `696cc493`
with the same e415 runtime passed an isolated local helper adoption gate: build
and all 85 acceptance checks, including 29 typed checks. Its three genre
publication plans exactly match the bda/e415 checkpoint. See
[the successor evidence](evidence/codec-successor.json). The earlier isolated gate granted no publication. The later selected public
adoption covers ordinary consumer publication and fresh hosted/cold starter
acceptance; alias/config/v4, merge and cleanup remain outside its scope.

## Entry-selected, type-derived authoring

The current local authoring slice removes redundant export annotations and the
`output` block argument. `entry` selects and validates a scalar export; the Lean
result type chooses text or an isolated Html preview. Imported scalar and Html
functions get document-owned callable adapters, so ordinary source producers
need no VIR annotation or separate root bundle. Register document/carrier pairs.

Keep `input`, `+multiline` and `+collapsed`, and reuse Verso's existing project/
module defaults for anchors. The shared signature contract, scalar worker codec,
real Stop and genre-native source remain. Runtime and dependency pins stay fixed.
The independent starter remains on its qualified older public revision until a
separately selected dependency/publication update. The earlier isolated codec
checkpoint remains preserved, independently of this new main-tree API slice.

## Inline authoring in every genre

`leanRun` now defines or reuses a function directly in Manual, Blog Page/Post and
Slides. Definitions, namespaces and open declarations are retained across Run
blocks. `entry`, input and the two presentation flags remain the same; typed Html
is adapted automatically. Anchors are optional when documents share source.

The shared Inline helper selects and validates callables after command elaboration.
It uses Verso's generic command engine, currently in the Manual library, with native
Blog code rendering; Slides supplies its formatting-aware elaborator and source.
Ordinary Blog named example contexts keep their original semantics. Publication,
codec and worker lifecycle remain shared. No new dependency or runtime is selected.

## Native build improvements

VIR [PR #223](https://github.com/ejgallego/lean-vir/pull/223) separates native
compiler libraries from JavaScript-only externs. Its landed compatible source
is selected in the public adoption above. Native consumer precompilation remains
a separate deferred slice: qualify it explicitly and measure cold/warm
builds and author iteration. Keep browser runtime matching and ordinary consumer
acquisition intact; do not combine this with compiler scheduling changes.

## Later Verso upstreaming slice

Group Verso core work for later review: the public highlighting hook and any
shared hooks required by the anchors/genre work. Discuss compiler scheduling
with the compiler maintainer before changing `compiler.postponeCompile false`.
Native precompilation remains deferred until its own consumer qualification is
selected; the landed source adoption does not enable it.

## Deferred qualification

General Illuminate diagrams require the recorded VIR float-provider work in
`evidence/illuminate-gates.md`. Wider browser and accessibility qualification
remain later work. Editor support and the more ambitious `verso-lab` project
are separate from this compiled Run extension.
