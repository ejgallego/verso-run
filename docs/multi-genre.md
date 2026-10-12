# Source anchors and multiple genres

Manual, Blog Page/Post, and Slides share function selection, source loading,
publication, and browser execution. Each genre supplies its own source renderer,
document traversal, and navigation behavior. This keeps Run blocks consistent
while preserving the features of their surrounding document.

For block syntax and examples, see [authoring](authoring.md),
[Blog authoring](blog.md), and [Slides authoring](slides.md).
The [architecture notes](internals.md) describe library and resource ownership;
[project history](history.md) records earlier designs and qualification checkpoints.

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

The displayed-body check lives in Verso's internal `moduleContentBlock`, not in
`withAnchored`. If an adapter called the public loader alone, it would skip this
standard authoring check. The adapter first checks that the selected declaration
belongs to the anchor through `withAnchored`, then calls Verso's `anchor` expander
for body checking and source construction. The second lookup uses Verso's
populated cache. This reuses Verso's comparison and suggestions without copying
its internal implementation or changing the pinned Verso code.

[SubVerso's anchor implementation][subverso] also rejects duplicate, unmatched,
and unclosed markers and retains highlighting and proof-state metadata. An
anchor can contain several declarations. Its name does not identify a callable.

## Common and genre-specific parts

| Responsibility | Shared implementation | Genre adapter |
| --- | --- | --- |
| Source selection | Existing external-code loader and checked anchor selection | `ExternalCode` instance; native source block and options |
| Callable description | Explicit entry, VIR classification, supported forms, diagnostics, actual export types | Inline command elaboration and scope handling, where supported |
| Run block | Portable `Experiment` data and common console HTML | Typed wrapper containing native source children; encoding and decoding its metadata |
| Publication | Match actual declarations to supplied bundles, validate contracts, prepare one VIR resource inventory and form bindings | Gather experiments from documents/site, select output root, write through the generator's asset mechanism |
| Browser execution | Input validation, dedicated worker, expected-export checks, Stop, stale-result suppression, HTML isolation | Asset URL supplied by the genre; navigation/visibility lifecycle hooks |
| Static rendering | Source-first fallback policy | Native links, proof states, code styling, and supported output formats |

The core depends on Verso's shared document types and VIR, without importing
`VersoManual`. Each genre adapter imports that shared core. The callable model
and classifier, console renderer, and publication planner remain separate so
each part has a clear responsibility.

Each Run adapter wraps an experiment with its native source children, decodes
that wrapper during AST traversal, and renders it with the shared console. The
block-tree walk is shared; Blog site traversal and Slides output remain genre
specific. Invalid wrapper metadata causes publication to fail rather than being
silently treated as an unrelated block.

`Model`, `Callable`, `Render`, `Collect`, and `Publication` provide the shared
implementation. `Anchored` supplies source authoring; `Manual`, `Blog`, and
`Slides` supply their genre wrappers. See the
[library map](internals.md#library-boundaries) for their source directories and imports.

## Keep four identities separate

1. **Displayed source:** project, module, and anchor. This can select several
   definitions or just part of a larger example.
2. **Callable:** the explicitly selected Lean declaration and its compiled
   expected signature. Publication finds the bundle that owns the callable;
   VIR checks the full declaration before invocation.
3. **Document location:** the genre's normal labels, links, and rendered paths.
4. **Form instance:** one placement and one worker owner. Displaying the same
   anchor or callable twice must still create independent forms.

An anchor does not import its module into the document's Lean environment or
establish a VIR contract. The producer must be imported into the document and
compatible with the pinned build; Lean classifies the explicitly selected entry
from that environment. The highlighted source does not determine its type or
export name. External highlighting may succeed with another toolchain, which
does not establish that the compiled function can run here.

Diagnostics retain both the document position and source selection. In
`Experiment`, `program` identifies the document and its binding. `producerModule`
records the module that owns the compiled callable and selects its bundle; the two
values serve different purposes.

The entry-selected API creates document-owned forwarding exports for
imported functions and preserves each admitted result type. The producer remains
ordinary Lean; its IR is included as a dependency of the document bundle. The
anchored HTML path is qualified through VIR's structured codec.

## Adapter findings

**Manual:** the Run wrapper retains the highlighted block produced by
`ExternalCode Manual` as a child. Traversal registers its definitions, and the
native renderers preserve reference links, `defSite`, proof states, and TeX.
Converting the source to a raw HTML string before traversal would bypass these
features. Inline `leanRun` works across all three genres through shared function
selection and registration with native source renderers; external anchors are an
optional way to reuse source. Slides keeps its formatting-aware command
elaborator. Blog Run definitions remain available in the document environment,
while ordinary Blog example contexts remain separate.

**Blog, Page and Post:** one adapter uses Blog's highlighted-code blocks and
components. Its component metadata has a different encoding from Manual's
extension data, so the adapter decodes it separately. Components supply the
shared scripts and styles. `VersoLeanRun.Blog.blogMain` collects the typed site,
validates the shared publication plan, calls Blog's generator, and writes binary
resources.
Manual and Blog output include a `<base>` tag. Blog forms carry explicit renderer
paths derived from their traversal location; [`bootstrap.js`](../web/bootstrap.js)
resolves these against the page URL. Manual keeps its base-relative default. Root and
nested copied Blog sites exercise this distinction. Also, pinned Blog
does not implement Manual's `defSite` policy: preserve Blog's existing code/link
behavior rather than promising identical definition targets.

**Slides:** the selected [public review snapshot][slides-assets] has native
highlighted code and Reveal fragments. The adapter uses `ExternalCode Slides`
so Run blocks keep those renderers and fit their source and controls into the
slide layout. Each block is a marked wrapper around native source blocks and the
shared controls; the closed Slides block type remains unchanged. Publication
reads the wrapper metadata from the typed document before generation.
`+collapsed` is applied in the browser, while the no-JavaScript layout retains
readable source.

The shared `preparePublication` planner accepts a complete `ResourceSet` and an
optional prefix. Each genre publisher collects its documents' experiments and
passes them with the resource set to this planner. Slides combines its Run
programs with the formatter's assets and requires the same runtime identity
before publication. Its inventory uses `lib/vir/` and includes the native
formatter. Binary assets enter Slides' normal collision checks through
`Config.extraAssets`. Built-in CSS and fonts keep their original paths; custom
themes and other settings are preserved. All genres use the same validated
resource inventory rather than separate planners or HTML scraping.

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
JavaScript; this adapter does not add a Blog TeX backend. Slides retains readable HTML source without JavaScript.

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
forwarding-export checks, including typed HTML, when changing the callable boundary. Run `lake build`, then
`lake test -- --mutations` sequentially. See [validation](validation.md) for the
current campaign and limitations. Dependency updates still require a matched
source/runtime pair and consumer qualification.

[external]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso/Verso/Code/External.lean
[manual]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso-manual/VersoManual/ExternalLean.lean
[blog]: https://github.com/ejgallego/verso/blob/aff0fc92d7b9e56a3b309d409b7ef69629af3770/src/verso-blog/VersoBlog.lean
[subverso]: https://github.com/leanprover/subverso/blob/9b90b7f938d6169246325df002351014f49945ef/src/SubVerso/Highlighting/Anchors/Basic.lean
[slides-basic]: https://github.com/ejgallego/verso-slides/blob/6e514cd443a51a39d92534b5a2ef08a5e47ed262/VersoSlides/Basic.lean
[slides-assets]: https://github.com/ejgallego/verso-slides/blob/6e514cd443a51a39d92534b5a2ef08a5e47ed262/VersoSlides/Render.lean
