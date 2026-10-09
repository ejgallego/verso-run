# Source anchors and multiple genres

Source review dated 2026-10-07; Blog and Slides implemented 2026-10-08.
Manual, Blog Page/Post, and Slides reuse the common execution boundary.
The [dependency pins](internals.md#pinned-dependencies) and public
`VersoLeanRun` / `VersoLeanRun.Publish` imports remain unchanged.

The first Manual implementation now extracts the common modules and adds
`leanRunAnchor`. It uses the standard expander, requires an imported same-project
scalar entry defined in the selected region, and retains native source children.
See [authoring](authoring.md#run-an-anchored-example-from-an-imported-module).
Its original 77-check qualification is retained in [validation](validation.md).
The Blog adapter reuses that common source path; see [Blog authoring](blog.md).

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
could simplify this later, but no additional Verso patch is required for this adapter.

[SubVerso's anchor implementation][subverso] also rejects duplicate, unmatched,
and unclosed markers and retains highlighting and proof-state metadata. An
anchor can contain several declarations. Its name does not identify a callable.

## Common and genre-specific parts

| Responsibility | Shared implementation | Genre adapter |
| --- | --- | --- |
| Source selection | Existing external-code loader and checked anchor selection | `ExternalCode` instance; native source block and options |
| Callable description | Explicit entry, VIR classification, shape/output policy, diagnostics, compiled expected signature | Inline command elaboration and scope handling, where supported |
| Run block | Portable `Experiment` data and common console HTML | Typed wrapper containing native source children; encoding and decoding its metadata |
| Publication | Match actual declarations to supplied bundles, validate contracts, prepare one VIR resource inventory and form bindings | Gather experiments from documents/site, select output root, write through the generator's asset mechanism |
| Browser execution | Input validation, dedicated worker, expected-export checks, Stop, stale-result suppression, HTML isolation | Asset URL supplied by the genre; navigation/visibility lifecycle hooks |
| Static rendering | Source-first fallback policy | Native links, proof states, code styling, and supported output formats |

The core depends on Verso's shared document types and VIR, without importing
`VersoManual`. Keep the existing module names as compatibility facades over a
Manual adapter. Separate the callable model/classifier, console renderer, and
publication planner rather than creating one large genre class.

The narrow Run adapter contract is: wrap an experiment and native source children;
recognize and decode that wrapper during AST traversal; and render it using the
common console. The generic block-tree walk can be shared, while walking an
entire Blog site or preparing slide output belongs to its adapter. Malformed
metadata must fail publication, rather than being treated as an unrelated block.

Before extraction, the [Run module](../src/VersoLeanRun.lean) mixed the portable
`Experiment` and console with Manual's `block_extension`, inline elaborator, and
scope handling. The [publisher](../src/VersoLeanRun/Publish.lean) mixed
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

The initial anchored implementation required producer-owned scalar exports.
The current entry-selected API creates document-owned callable adapters for both
imported scalars and typed HTML. The original producer remains ordinary Lean;
its IR is included as a dependency of the document bundle. This qualifies the
previously deferred anchored Html path without changing VIR's scalar boundary.

## Adapter findings

**Manual:** retain the highlighted block produced by `ExternalCode Manual` as a
child of the Run wrapper. Its traversal registers definitions and its native
renderers preserve reference links, `defSite`, proof states, and TeX. Rendering
the source into a raw HTML blob before traversal would bypass these facilities.
The inline `leanRun` authoring mode now works across all three genres through a
shared selection/registration helper with native source renderers. External
anchors remain an optional source-reuse route. Slides retains its formatting-aware
command elaborator; Blog Run code is retained in the document environment, while
ordinary Blog example contexts remain separate.

**Blog, Page and Post:** one adapter uses the existing highlighted-code block
and component system. Component metadata uses a different encoding from Manual's
extension JSON, so decoding is adapter-specific. Components provide text JS/CSS
assets; `VersoLeanRun.Blog.blogMainResources` collects the typed site, validates the shared
publication plan, calls stock Blog generation, and writes binary resources.
Both genres emit a `<base>` tag. Blog forms carry explicit renderer paths derived
from their traversal location; [`bootstrap.js`](../web/bootstrap.js) resolves
these against the page URL. Manual keeps its base-relative default. Root and
nested copied Blog sites exercise this distinction. Also, pinned Blog
does not implement Manual's `defSite` policy: preserve Blog's existing code/link
behavior rather than promising identical definition targets.

**Slides:** the selected [public review snapshot][slides-assets] has native
highlighted code and Reveal fragments. The adapter adds `ExternalCode Slides`
using that fragmentization, without side panels or stretch for Run blocks. Its
closed block enum remains unchanged: a marked `.wrap` contains native source
children and shared console controls via `.ofHtml`. Collection strictly decodes
metadata from the typed AST before any generation. `+collapsed` is enhanced in
the browser; the no-JavaScript layout retains readable source.

The common `preparePublicationWithResources` planner accepts the complete resource
set and an optional prefix. The original Bundle APIs retain their defaults as
compatibility adapters. Slides combines with its formatter's set, requiring the
same runtime identity before publication. Slides uses
`lib/vir/` and includes the native formatter in the same resource set as the Run
producers. All binary files enter the stock asset collision plan through theme
assets. Built-in CSS and fonts retain their original paths; custom themes and
other settings are preserved. There is one compatible runtime inventory, with
no copied private asset planner or HTML resource discovery.

Reveal slide changes and fragment hide events terminate affected Run workers,
cancel pending loading, clear previews, and reject stale results. Showing the
form again allows a fresh call. Hidden forms cannot submit, and input key events
do not navigate Reveal. Source fragments remain native.
Scroll navigation also cancels work. Restoring Reveal's saved HTML when leaving
scroll view disposes detached workers and reattaches the restored forms.

The selected Slides revision uses module-owned VIR assets on Lean 4.35.0-rc4.
The root package locks VIR and Verso explicitly, overriding Slides' dependency
selections. Verso retains the Manual highlighting hook and adds the upstream
base-85 proof and deprecation-check adjustments required by Lean 4.35.
Illuminate retains its original revision. See the [dependency table](internals.md#pinned-dependencies)
for the exact source/runtime pair. The Slides pin is a review snapshot; upstream
integration remains separate from this consumer's qualification.

Only Manual's TeX fallback is established. Blog retains native source without
JavaScript; this adapter does not add a Blog TeX backend. Slides should retain
its own supported static output; Slides now has a readable HTML fallback.

## Acceptance invariants

The shared extraction, anchored Manual integration, Blog Page/Post adapter, and
Slides integration are implemented. Their development sequence is recorded in
[history](history.md); future changes must preserve the shared resource graph and
native source rendering.

Acceptance covers missing/duplicate/unclosed anchors, stale block bodies,
explicit entry resolution and unsupported interfaces, missing producer bundles,
conflicting logical IDs, and missing root declarations. Repeated placements keep
independent workers. Root/nested hosting, actual Stop, native fragments, and
JavaScript-disabled source remain required behaviors. An entry must belong to
the selected anchor's semantic declaration set; an anchor name or token spelling
alone does not establish that relationship.

Retain rejected-build/no-fresh-publication mutation checks and document-owned
HTML-adapter checks when changing the callable boundary. Run `lake build`, then
`lake test -- --mutations` sequentially. See [validation](validation.md) for the
current campaign and limitations. Dependency updates still require a matched
source/runtime pair and consumer qualification.

[external]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso/Verso/Code/External.lean
[manual]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso-manual/VersoManual/ExternalLean.lean
[blog]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso-blog/VersoBlog.lean
[subverso]: https://github.com/leanprover/subverso/blob/9b90b7f938d6169246325df002351014f49945ef/src/SubVerso/Highlighting/Anchors/Basic.lean
[slides-basic]: https://github.com/ejgallego/verso-slides/blob/daa96fee635f289e2be95982418483bfb4351402/VersoSlides/Basic.lean
[slides-assets]: https://github.com/ejgallego/verso-slides/blob/daa96fee635f289e2be95982418483bfb4351402/VersoSlides/Render.lean
