# Next slices

The project has a copyable Manual starter and a GitHub Pages deployment workflow.
Keep exact dependencies and the current execution boundary.

## Public runtime integration gate

The hosted demo currently fails during Run because the frozen loader rejects
GitHub Pages' JavaScript MIME type. VIR's owner has qualified a MIME fix and a
matching successor pack locally. Adoption waits for verified source publication,
explicit public runtime release selection, and a complete source/runtime handoff.
Do not repin or substitute local producer packs before that gate is open.

The successor also changes registration, export lookup, and numeric transport.
Its later integration needs independent author-starter acquisition and hosted
worker qualification, alongside the existing native/browser acceptance checks.

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

Further dependency-closure diagnostics and new runtime/schema behavior should
be reviewed with the VIR owner during successor integration. See
[troubleshooting](docs/troubleshooting.md) and [validation](docs/validation.md).

## Verso anchors and multiple genres

Review alignment with Verso's ANCHORS guidance and anchor/link behavior, then
support Manual, slides, and blog documents. Separate the callable description,
resource publication, and worker interaction from genre-specific elaboration,
rendering, document traversal, and source highlighting. Preserve each genre's
normal anchors, links, styling, and static fallback. Qualify an independent
example in each genre before claiming support beyond Manual.

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
