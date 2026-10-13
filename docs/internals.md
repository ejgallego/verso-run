# How verso-run fits together

## Library boundaries

The package has separate Lake owners for model/view code, browser presentation,
and document authoring. Import `VersoLeanRun.Views` in ordinary Lean producer
modules. Document modules select `VersoLeanRun`, `VersoLeanRun.Blog`, or
`VersoLeanRun.Slides`; their native generators select the corresponding `Publish`
module. Existing directive and publication APIs retain their names.

| Library | Source directory | Owned modules |
| --- | --- | --- |
| `VersoLeanRunViews` | `src/views/` | `Views`, `Frame`, `Sequence`, `Automaton` |
| `VersoLeanRunAuthoring` | `src/authoring/` | `Model`, `Callable`, `Anchored`, `Inline`, `Render`, `Collect` |
| `VersoLeanRun` | `src/manual/` | Manual facade and `Manual` |
| `VersoLeanRunPublish` | `src/publication/` | `Publish`, `Publication` |
| `VersoLeanRunBlog` | `src/blog/` | `Blog`, `Blog.Publish` |
| `VersoLeanRunSlides` | `src/slides/` | `Slides`, `Slides.Publish` |
| `VersoLeanRunPresenter` | `src/presenter/` | `VersoLeanRunPresenter`, `Preview` |
| `VersoLeanRunPresenterResources` | `src/presenter-resources/` | Native presenter resource carrier |

Each library's `srcDir` is disjoint. Module paths within these directories retain
their public Lean names, so moving files does not change imports. Explicit module
globs give every source one owner even where namespaces overlap; namespace-wide
roots would also claim modules in other libraries. `lake run check-library-ownership`
checks that every source is registered to the library whose directory contains it.

The views library has no
browser-asset prerequisite and imports no genre adapter, VIR compiler or DOM
binding. The presenter depends on view types; authoring depends on views and the
native compiler APIs. Native publication imports the presenter carrier. That
carrier classifies the prepared program in an elaboration-time environment and
embeds its resources, keeping the DOM implementation out of ordinary native
imports.

The pinned `Verso.Output.Html` also imports its Lean quoter machinery. VIR's DOM
bindings import host validation through `Vir.Host`, including VIR classifier
modules. These upstream imports remain intact. Separating their syntax and
runtime data would require an upstream change; this split makes verso-run's
ownership explicit and does not claim a compiler-free transitive DOM import or
a measured build-speed improvement. VIR packages executable declarations through
their reached IR dependencies.

`tests/client.py` checks source-directory ownership and import phases, then runs a
plain Lean producer through native and dedicated-worker execution without a
Verso document, page host or presenter. Compiler expectations are derived
independently by its native carrier. See [validation](validation.md).

The public view modules use Verso module prose and checked examples. Reference
generation is an explicit documentation step, without adding a prerequisite to
the view library. `literate.toml` selects that library for Verso's HTML pipeline;
the source freshness helper and preview commands are described in
[Contributing](../CONTRIBUTING.md#generated-library-reference).

## Common machinery and Manual integration

The portable model, callable classifier, anchor loader, console, AST collector
and publication planner have no dependency on `VersoManual`: `Model` retains portable
experiment data, `Callable` selects/registers entries and builds expected contracts,
`Anchored` reuses standard checked source anchors, `Render` builds the console,
`Collect` walks a genre's AST with its extension decoder, and `Publication`
prepares the complete validated file inventory without writing it.

`Inline` shares entry selection and retained command scopes after elaboration.
It reuses Verso's generic command engine, currently located in the Manual library;
it constructs no Manual AST. `Manual` supplies its native highlighted source and
Run wrapper. Blog supplies native Page/Post code blocks; Slides supplies its own
formatting-aware command engine and native fragmentized source. `Publish` decodes
Manual wrappers and writes the common plan into
the selected HTML layout. Public imports remain `VersoLeanRun` and
`VersoLeanRun.Publish`. Blog adapters collect typed Page/Post sites. Slides adapters
retain native source wrappers and compose Run resources with the stock formatter
asset plan. Both reuse the same model, source loader, console, and worker.
The [genre design](multi-genre.md) describes those boundaries.

## Resource ownership and site integration

Follow VIR's stock resource workflow, demonstrated by the
[lakefile](../lakefile.lean) and [carrier](../demo/resources/LeanRunGate/Resources.lean):

1. Register the document as a program library. `entry` validates and registers
   local scalar entries; imported functions and typed HTML get document-owned
   callable adapters. Imports supply their compiled dependency closure. Ordinary
   producer modules need no VIR annotations or separate root resource bundles.
2. Register a disjoint resource carrier library with the explicit module resource facet
   in `needs`:

   ```lean
   lean_lib MyResources where
     srcDir := "resources"
     roots := #[`MySite.Resources]
     needs := #[`+MyChapter:virResourcePack]
   ```

   The demo registers the Manual chapter, Blog Page/Post and Slides deck as
   separate document roots. There are no JSON recipes or handwritten interface
   IDs. Keep document and carrier libraries disjoint.
3. Embed the complete prepared resource set in its carrier library. The chapter imports
   extension support, never its carrier:

   ```lean
   module
   public import Vir.Resources.Assets

   public def MySite.resources : Vir.Resources.ResourceSet :=
     include_vir_assets (modules := #[MyChapter])
   ```

   The include names the program module and returns a `ResourceSet` containing
   the locked runtime and prepared programs. Pass this value directly; no singleton
   extraction or reconstruction of runtime ownership is needed.
   Module resource facets support custom source/build directories.
4. Import the chapter, carrier, and `VersoLeanRun.Publish` in the native generator:

   ```lean
   def main := manualMain (%doc MyChapter)
     (extraSteps := [VersoLeanRun.publish MySite.resources])
   ```

   Pass every required document's complete set. `combineResources` appends programs
   in order when both sets use the same runtime content identity. It checks a distinct
   runtime inventory before discarding it; identical inventories need no repeated check.
   Publication validates the final set once through VIR's `forSite`, which owns
   program compatibility, deduplication, and conflict checks. Manual and Blog preserve
   the supplied runtime. Slides combines with its embedded formatter set and rejects
   a different supplied runtime before generation.

`preparePublication` is the common pure planner; its optional `resourcePrefix`
controls inventory paths. Manual uses `publish`, Blog uses `blogMain`, and Slides
uses `slidesMain`. Each accepts a complete `ResourceSet`. This prototype has no
backward compatibility policy: Bundle-array adapters and serialized metadata
fallbacks have been removed. Migrate callers when updating the pin.

The graph remains support → producer → document → program preparation → carrier →
native generator. No per-block packaging or second execution compiler is added.
Verso's standard external-code path prepares cached highlighting separately.

`Experiment.program` identifies the document placement group; `sourceLine` and
`sourceColumn` locate the block for diagnostics. `declaration` is the author-selected
Lean entry. `callable` is the full
compiled VIR export name.
`producerModule` identifies the callable's owning module. Generated scalar/Html
adapters for imported entries belong to the document, leaving producer modules
unchanged. Source anchor names and callable export names remain separate.
The native block metadata retains these identities and source locations for
collection and publication diagnostics. At HTML rendering, `data-experiment`
contains only `program`, `declaration`, `callable`, `form`, `initialInput`, and
`collapsed`. The browser uses document/entry identity to resolve the published
manifest and expected contract, and callable identity to select the export.
Producer ownership and source coordinates remain native; they are not sent to
the worker. Rendering uses an explicit whitelist rather than serializing the
complete native metadata record; `Experiment.browserDescription` in `Render`
defines that whitelist. Slides keeps its full wrap metadata through
native collection and publication, then uses Verso's block rewrite to project
only the experiment attribute before the stock renderer sees it. Native source
children, fragments, and other attributes retain their structure.

The publisher matches this module to the generated bundle's `logicalId` and
preserves the original index-to-manifest mapping. Identical bundles deduplicate.
Distinct bundles with one logical ID fail `ResourceSet.forSite` validation with
`LOGICAL_ID_CONFLICT`, before per-form binding or output writes.

Bindings are keyed by document and author-selected declaration. Repeated placements
share one manifest and expected signature while retaining independent controls,
inputs, and workers. Changing the callable, manifest, or scalar expectation for
that same key fails with `PUBLICATION_BINDING_CONFLICT`, reporting both source
locations before any publication writes. Input presets, collapsed state, and
String input mode does not change the callable contract. Result presentation can
change its transport type. Different
documents have independent binding namespaces. Ordered binding maps produce the
same publication bytes regardless of placement order.

Publication validates resources, module availability, and independent expectation
construction. VIR's `createProgram` validates actual root declarations and their
signatures before runtime instantiation. `forSite` does not check callable types;
there is no embedded-interface parser or reopening of producer files here.

VIR's `analyzeExportInterface` independently classifies the callable. Plain-text
calls retain pure, homogeneous String/Nat/Bool/UInt64 signatures. Any of these
inputs may instead return `Html` or `SequenceView`. `Experiment.form : FormKind`
contains an `InputKind` and `PresentationKind`; multiline mode exists only inside
`InputKind.string`. Unknown tags and unsupported object encodings fail metadata
decoding. The fifteen wire names are checked against the shared browser codec.

Html adapters retain the actual input type and return markup Strings. Sequence
adapters return `SequenceWire.Payload` with arrays, labels, markup and optional
errors. VIR's native structure codec converts these values; worker messages use
structured clone, including exact BigInt fields. Publication constructs primitive
contracts through VIR's canonical encoder and derives structured contracts from
the actual compiled payload type. Both are independent of downloaded executables.

Shape, display mode, and multiline controls are derived from this form. A second
signature or JSON encoded inside a String is no longer carried in every experiment.
Publication encodes the retained type through VIR's `ClassifiedSignature` encoder
as `{args, result, effect}` in `expectedExport`. The worker uses the full Lean
`callable` declaration as both expectation key and call name. A missing expectation
fails before worker creation. Missing declarations or argument/result/arity/effect
mismatches fail in VIR's program-validation phase before invocation. Native/browser
oracle comparisons establish the demonstrated semantic agreement.

The native executable embeds UI files and complete program/runtime bytes and runs
outside the checkout. Verso still requires a `lean-toolchain` marker in its working
directory or a parent. Retain `compiler.postponeCompile false`; native precompilation
and alternative embedding APIs remain deferred.

## Interaction and limits

Execution resources load only on first Run. Separate activated forms have independent
execution state. Stop terminates the dedicated worker, including pending creation or
synchronous execution; another Run creates a fresh instance. Publication loading
returns a cancellable invocation immediately. Concurrent placements share acquisition;
cancelling its last waiter aborts the pending fetch. Failed acquisition is evicted,
and a 15-second deadline gives an explicit retry path. Scalar/Html/sequence input changes terminate
current work and clear the old result. Automaton input changes are drafts; Restart
applies them to a fresh session. Generation and request identities suppress stale
results. Duplicate submissions are disabled while loading/running, except an explicit
live Restart may cancel an active transition and replace the session. Page navigation
disposes each owner. Resource and runtime errors are displayed as text, and failure never
automatically replays the previous call.

Natural inputs use validated decimal text. VIR returns nonnegative JavaScript
`BigInt` values; the worker formats exact decimal display text before posting the
result. No conversion to JavaScript `Number` occurs. Reject negatives, whitespace, decimals, exponent notation,
and non-digits before invoking. Limits are 4,096 UTF-16 code units for a String input, 256
digits for a Nat input, and 65,536 UTF-16 code units for displayed output. These are
input/output bounds, not a Wasm heap budget. Stop provides actual interruption; execution
of trusted compiled code can allocate memory before an output limit is checked. Arbitrary
Lean evaluation, custom foreign-function providers, author-selected browser IO/DOM/React
exports, tactics, and general dependent interfaces are outside this milestone. The
internal sequence presenter separately qualifies its exercised DOM bindings.

Forms group the highlighted source above a quiet input/result area, with aligned controls,
visible keyboard focus, and wrapping on narrow screens. They have labels, keyboard
submission, accessible status updates, escaped text output, and disabled controls until
enhancement. Source remains available without JavaScript, and TeX renders the same
highlighted source without interactive controls.


## Pinned dependencies

| Component | Pinned revision |
| --- | --- |
| Lean | 4.35.0-rc4 (required by VIR PR #229) |
| Verso | `aff0fc92d7b9e56a3b309d409b7ef69629af3770` |
| VIR | `957854b9df1202d4fadbd00ac5fa34e5adf278cc` (PR #229 head) |
| Illuminate | `a1a61c9678da010e958ed24cdfa6f635b85f172a` |
| Slides | `6e514cd443a51a39d92534b5a2ef08a5e47ed262` (public review snapshot) |
| Runtime | `6cddc4b897410d7524a69bdaff0327d9f07916735078a0b12d548e2f88c23d20` |

The minimal Verso fork is based on release `cad4b633` and exposes the existing
`toHighlightedLeanBlock` helper; it contains no demo code. The runtime uses VIR
compatibility version 3 (resource descriptor version 2). Lake acquires and verifies VIR's locked runtime, so
authors do not need a separate SDK installation or Wasm build.


The VIR pin is the exact source head selected from PR #229. Its Lean toolchain
and runtime lock must be qualified together. Verso adds the upstream base-85 digit proof and deprecation-check adjustment needed by Lean 4.35, while
Slides uses its module-owned-assets review snapshot. Illuminate retains its pin; consumer acceptance is recorded separately in
[validation](validation.md).

## Sequence presentation boundary

`Sequence α` and `SequenceStep α` hold the author's model. Its lawful `Functor`
instance maps observations while retaining labels and errors. `List.scanl` records
exactly the requested transitions. `.view` uses an
`α → Html` function and produces a concrete `SequenceView`. Both sequences and
views require an initial record, making their nonempty invariant structural.
`Sequence.iterate` traces a pure `α → α` automaton for an explicit transition count;
`SequenceView.error` reports an input failure without inventing a model state.
Entry elaboration reduces the result type to recognize aliases before choosing
a document-owned typed payload adapter and independently classifies its
actual export signature. Publication adds the separate presenter program and its
compiler-derived DOM contracts whenever rendered views are present. The
presenter carrier retains its complete `ResourceSet`; `combineResources` checks
its runtime identity against the supplied set before publication. Its manifest
is resolved by module identity rather than inventory position.

The native generator embeds the presenter resource pack without statically
importing its browser-only definitions. The carrier loads the prepared module's
compiled environment to classify the actual `mount`, `mountHtml`,
`stageAutomaton`, and `commitAutomaton` declaration types. It does not infer a contract from the executable manifest or elaborate another source
frontend. This keeps JS externs out of native C compilation.

`VersoLeanRunPresenter` uses VIR's existing DOM/event/RuntimeRef APIs. It owns
Html preview documents, selection, scrubbing, frame display and exact listener identities. Its cleanup
callback removes listeners before the JavaScript lifetime bridge disposes the
runtime. The bridge handles asynchronous acquisition, generation checks, Stop
and failure/retry. Computation stays in the dedicated worker; the presenter runs
in the browser context and receives rendered frame data, not worker DOM handles.
State frames retain the restrictive Html sandbox. Genre adapters reuse their
existing placement and navigation lifecycle.

### On-demand automata

`Automaton α` retains the pure initial/transition interface. `Automaton.view`
returns an `AutomatonView` whose start action allocates a worker-owned
`RuntimeRef (α × Nat)`. The document adapter runs that action and returns an
`AutomatonWire.Session`: an initial frame and a zero-argument, runtime-effect
advance callback. Publication independently classifies that exact nested
contract through VIR. This effect belongs to the generated session adapter;
ordinary scalar exports retain their pure interface.

`Frame` and `ViewWire.Frame` are shared observations; `Frame.toWire` is the one
Html-to-markup conversion. `Automaton.observe` permits domain-specific labels and
errors. `Automaton.trace` creates a finite observation without starting a session;
`Sequence.cycleView` explicitly replays stored observations with a bounded `Fin`
cursor. Replay is not reconstruction of a transition function.

The worker retains the callback and current model. Advance messages call it and
transfer one validated `ViewWire.Frame`; neither the callback nor a DOM handle
crosses `postMessage`. Reinitialisation creates a fresh worker so old session
handles cannot accumulate. The presenter stages the next sandbox document in a
second iframe, then commits
the frame and its label together after loading. The visible iframe is never
navigated during a transition. If the tab becomes hidden after the document has
loaded, the pending paint wait settles; an unloaded document must still load or
be cancelled. Abort, visibility and load listeners belong to that one wait and
are removed on settlement. Both stage and commit exports have independently
classified DOM contracts. JavaScript owns asynchronous scheduling with one request in flight and a delay between
completed transitions; Pause keeps the session, while Stop/navigation terminate
it. Input edits remain a draft until Restart. Generation checks also discard late
completions after a reset.
Page load and slide entry are idle. Restart resumes only previously active
playback; hiding, Stop, cached-page exit or genre exit cancels pending resume
intent. Returning to visibility does not resume automatically. Event handlers
from retired controls cannot act on a replacement session. Error observations
disable Play/Step, while Stop can still release their worker.
There is no growing frame history. A cycling trace retains its fixed recorded
states; an ordinary live model keeps only its current state.

### Rendering and transport

Authors return typed `Html`, `SequenceView`, or `AutomatonView`. Html generation, including SVG,
runs in compiled Lean in the worker. The sequence controls and frame selection
also run in compiled Lean, in the separate browser presenter. JavaScript owns
asynchronous loading, worker messages and cancellation; it does not evaluate the
model or interpret the sequence's meaning.

Sequence transport is typed data, with no JSON encoding or parsing in the execution
path. Html markup remains a String at the sandboxed document boundary. Both previews
use `Preview.document` in compiled Lean, so their CSP and document style have one
implementation. The browser bridge owns loading and disposal, not document markup. DOM references and callbacks remain owned by
the browser presenter and must not cross the worker boundary.

Lake already supports this split through the presenter library's module resource
facet and its separate carrier. Extending that compiled presentation library
does not require a new Lake rendering API. Its generated resources must remain
outside the modules they embed, as with document programs.

Stop and the loading deadline settle the module-import wait. They do not cancel
ECMAScript import or its possible later evaluation. Late rejection stays observed,
and generation checks prevent an abandoned wait from creating a presenter.

The current Verso Html string serializer can omit closing tags for empty non-void
elements. Presenter control paragraphs and the iframe have explicit bodies so
fragment parsing preserves their sibling relationship. This belongs with the
later Verso upstreaming review; the dependency pin is unchanged.
