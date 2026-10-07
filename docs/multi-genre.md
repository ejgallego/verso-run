# Source anchors and multiple genres

Review dated 2026-10-07. This is an implementation proposal based on source
inspection, not qualification of new genres. Manual remains the supported genre.
The [dependency pins](internals.md#pinned-dependencies) and public
`VersoLeanRun` / `VersoLeanRun.Publish` imports remain unchanged.

The first Manual implementation now extracts the common modules and adds
`leanRunAnchor`. It uses the standard expander, requires an imported same-project
scalar entry defined in the selected region, and retains native source children.
See [authoring](authoring.md#run-an-anchored-example-from-an-imported-module).
Its 77-check qualification is retained in [validation](validation.md). Blog and
Slides remain proposals.

## What Verso already shares

Verso's source anchors select regions between `-- ANCHOR: name` and
`-- ANCHOR_END: name` in compiled example modules. They are distinct from document
labels and URL fragments.

The pinned [external-code implementation][external] already separates loading
from presentation:

- `anchored` loads SubVerso's highlighted module data, selects anchor regions,
  and caches by project, module, and suppressed namespaces. Reuse this machinery;
  do not introduce another anchor parser or highlighting frontend.
- `withAnchored` passes the selected `Highlighted` value to a callback and
  reports missing anchors with suggestions.
- `ExternalCode genre` supplies genre-native Lean blocks, inline code, and
  messages. [Manual][manual] and [Blog][blog] already implement it. Blog's
  `BlogGenre` abstraction covers both Page and Post.
- Standard `anchor` blocks also check that the displayed block body matches the
  selected source, ignoring blank lines. An empty body for nonempty source is an
  error with a fill-in suggestion. A mismatched body gets a replacement hint.

That last check lives in internal `moduleContentBlock`, not `withAnchored`.
Calling the public loader alone would silently lose the standard authoring
checks. The implementation first checks semantic definition membership through
`withAnchored`, then calls the standard `anchor` expander for body checking and
source construction. The second lookup uses Verso's populated cache. No copy of
the internal comparison or suggestion code is needed. A checked callback helper
could simplify this later, but no additional Verso patch is required for this slice.

[SubVerso's anchor implementation][subverso] also rejects duplicate, unmatched,
and unclosed markers and retains highlighting and proof-state metadata. An
anchor can contain several declarations. Its name does not identify a callable.

## Proposed common and genre-specific parts

| Responsibility | Shared implementation | Genre adapter |
| --- | --- | --- |
| Source selection | Existing external-code loader and checked anchor selection | `ExternalCode` instance; native source block and options |
| Callable description | Explicit entry, VIR classification, shape/output policy, diagnostics, compiled expected signature | Inline command elaboration and scope handling, where supported |
| Run block | Portable `Experiment` data and common console HTML | Typed wrapper containing native source children; encoding and decoding its metadata |
| Publication | Match actual declarations to supplied bundles, validate contracts, prepare one VIR resource inventory and form bindings | Gather experiments from documents/site, select output root, write through the generator's asset mechanism |
| Browser execution | Input validation, dedicated worker, expected-export checks, Stop, stale-result suppression, HTML isolation | Asset URL supplied by the genre; navigation/visibility lifecycle hooks |
| Static rendering | Source-first fallback policy | Native links, proof states, code styling, and supported output formats |

The core should depend on Verso's shared document types and VIR, without importing
`VersoManual`. Keep the existing module names as compatibility facades over a
Manual adapter. Separate the callable model/classifier, console renderer, and
publication planner rather than creating one large genre class.

The narrow Run adapter contract is: wrap an experiment and native source children;
recognize and decode that wrapper during AST traversal; and render it using the
common console. The generic block-tree walk can be shared, while walking an
entire Blog site or preparing slide output belongs to its adapter. Malformed
metadata must fail publication, rather than being treated as an unrelated block.

Before extraction, the [Run module](../support/VersoLeanRun.lean) mixed the portable
`Experiment` and console with Manual's `block_extension`, inline elaborator, and
scope handling. The [publisher](../support/VersoLeanRun/Publish.lean) mixed
contract validation/resource planning with Manual AST decoding and `ExtraStep`
output selection. These boundaries now correspond to `Model`, `Callable`,
`Render`, `Collect`, and `Publication`, with `Anchored` supplying shared source
authoring and `Manual` supplying the genre wrapper. The browser host and worker
remain the shared execution layer.

## Keep four identities separate

1. **Displayed source:** project, module, and anchor. This can select several
   definitions or just part of a larger example.
2. **Callable:** explicit full Lean declaration plus its compiled expected
   signature. Publication selects its producer-module bundle; VIR admits the full declaration before invocation.
3. **Document location:** the genre's normal labels, links, and rendered paths.
4. **Form instance:** one placement and one worker owner. Displaying the same
   anchor or callable twice must still create independent forms.

An anchor neither imports its module into the document's Lean environment nor
proves a VIR contract. Initially, require the executable producer to be imported
and compatible with the pinned build, and classify the explicitly selected entry
from that environment. Do not infer types or export names from highlighted text.
External highlighting can use a different toolchain successfully; that alone
does not establish execution compatibility.

Retain both document-position and source-selection provenance in diagnostics.
The existing `Experiment.program` remains a document-owner/binding key. The
public-pair migration adds `producerModule` from Lean's actual declaration
ownership, which selects the generated module bundle independently of that key.

Typed HTML needs additional care: today's `leanRunHtml` wrapper is compiled in
the document module. Selecting source from another module does not transfer that
wrapper's ownership there. The first anchored example should use an already
exported scalar function. Then qualify HTML with an explicitly owned compiled
adapter and registered producer bundle, while keeping existing inline HTML working.

## Adapter findings

**Manual:** retain the highlighted block produced by `ExternalCode Manual` as a
child of the Run wrapper. Its traversal registers definitions and its native
renderers preserve reference links, `defSite`, proof states, and TeX. Rendering
the source into a raw HTML blob before traversal would bypass these facilities.
The inline `leanRun` authoring mode remains a Manual feature; external anchored
examples provide the shared route across genres.

**Blog, Page and Post:** one adapter can use the existing highlighted-code block
and component system. Component metadata uses a different encoding from Manual's
extension JSON, so decoding is adapter-specific. Components provide text JS/CSS
assets; binary VIR resources still need a site-generator publication hook or
wrapper. Nested post paths need explicit asset-root handling. The current
[`bootstrap.js`](../web/bootstrap.js) assumes `lean-run/renderer.js` is relative
to `document.baseURI`, which is a Manual layout convention. Also, pinned Blog
does not implement Manual's `defSite` policy: preserve Blog's existing code/link
behavior rather than promising identical definition targets.

**Slides:** the inspected [verso-slides source][slides-basic] has native
highlighted code and Reveal fragments but no production `ExternalCode Slides`
instance. Its block extension is a closed enum. Existing `.wrap` and `.ofHtml`
constructors offer a possible initial adapter: a marked wrapper with strictly
decoded experiment metadata, native source children, and common console HTML.
Retain the typed AST for collection; do not discover exports by scraping rendered
HTML. A dedicated Run constructor or open extension hook can be discussed later
if the minimal wrapper proves inadequate.

A Slides `ExternalCode` instance should reuse its existing code fragmentization,
panel, and stretch behavior. Reveal slide changes and hidden fragments also need
to terminate affected workers; page unload alone is insufficient. Check keyboard
submission against Reveal's shortcuts.

The Slides main checkout inspected here is `268257a4` on Lean 4.35.0-rc4, outside
our frozen Lean 4.34.0 build. A separate owner-managed 4.34 worktree at
`7bee77a0` demonstrates [VIR binary inventory integration][slides-assets] through
the normal asset plan, including collisions. It is useful design evidence, not
a selected dependency or a qualified verso-run adapter. Coordinate with that
publisher so a site containing both extensions has one compatible runtime plan.

Only Manual's TeX fallback is currently established. Blog and Slides should retain
their own supported static output; this proposal does not add TeX backends to them.

## Implementation order and acceptance

1. Extract the shared model, classifier, console, and publication planner behind
   the existing Manual facades. Preserve all current behavior and acceptance
   checks before adding another genre.
2. Add a checked anchored Manual example, with an explicit entry, imported
   producer, and unchanged resource graph: support → producer → preparation →
   carrier → generator. Qualify the source-loader's nested Lake/cache behavior
   and highlighting prerequisites; avoid a second per-form compiler pipeline.
3. Add one Blog adapter for Page and Post using the same anchored example.
   Qualify binary publication and nested-page asset URLs.
4. Add Slides after selecting a compatible revision with its maintainers.
   Qualify native fragments, asset-plan composition, and visibility-based Stop.

Acceptance should cover missing/duplicate/unclosed anchors, stale block bodies,
explicit entry resolution and unsupported interfaces, missing producer bundles, conflicting logical IDs, and missing root declarations, repeated placements of one callable, root and nested hosting,
independent workers, actual Stop, and static source without JavaScript. Specify
and test how an explicitly chosen entry relates to the displayed region; an
anchor's name or token spelling is insufficient evidence of that relationship.
Retain rejected-build/no-fresh-publication mutation checks. Add HTML adapter
ownership checks before claiming anchored HTML support.

For each implemented slice run `lake build`, then `lake test -- --mutations`
sequentially, plus executable/browser examples for newly supported genres.
New genre checks remain pending; the shared extraction and anchored Manual
implementation are described in the [validation record](validation.md).
The separate public VIR source/runtime adoption gate remains in force.

[external]: https://github.com/ejgallego/verso/blob/3f6366aa8045b342b0b68c0373a8ebfce7d5611f/src/verso/Verso/Code/External.lean
[manual]: https://github.com/ejgallego/verso/blob/3f6366aa8045b342b0b68c0373a8ebfce7d5611f/src/verso-manual/VersoManual/ExternalLean.lean
[blog]: https://github.com/ejgallego/verso/blob/3f6366aa8045b342b0b68c0373a8ebfce7d5611f/src/verso-blog/VersoBlog.lean
[subverso]: https://github.com/leanprover/subverso/blob/9b90b7f938d6169246325df002351014f49945ef/src/SubVerso/Highlighting/Anchors/Basic.lean
[slides-basic]: https://github.com/ejgallego/verso-slides/blob/268257a4fbdac12c77be726213b51c3ce3a1d41e/VersoSlides/Basic.lean
[slides-assets]: https://github.com/ejgallego/verso-slides/blob/7bee77a03c60b6423ed67a3a682fa85d1eb077c0/VersoSlides/Render.lean
