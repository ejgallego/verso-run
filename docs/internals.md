# How verso-run fits together

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
The [genre review](multi-genre.md) describes those boundaries.

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

`Experiment.program` identifies the document placement group and diagnostic
position; `declaration` is the author-selected Lean entry. `callable` is the full
compiled VIR export name.
`producerModule` identifies the callable's owning module. Generated scalar/Html
adapters for imported entries belong to the document, leaving producer modules
unchanged. Source anchor names and callable export names remain separate.
The publisher matches this module to the generated bundle's `logicalId` and
preserves the original index-to-manifest mapping. Identical bundles deduplicate.
Distinct bundles with one logical ID fail `ResourceSet.forSite` validation with
`LOGICAL_ID_CONFLICT`, before per-form binding or output writes.

Publication validates resources, module availability, and independent expectation
construction. VIR's `createProgram` validates actual root declarations and their
signatures before runtime instantiation. `forSite` does not check callable types;
there is no embedded-interface parser or reopening of producer files here.

VIR's `analyzeExportInterface` independently classifies the callable. Only pure,
homogeneous, single-argument String/Nat/Bool/UInt64 signatures are admitted.
`Experiment.form : FormKind` retains that scalar type and its allowed presentation.
Its String constructor carries a `StringInputMode` and `StringPresentation`;
Nat, Bool, and UInt64 have no presentation parameters. This lets additional String
views extend the presentation type without weakening scalar invariants. The wire tags are
`string`, `multilineString`, `nat`, `bool`, `uint64`, `html`, or `multilineHtml`.
HTML forms invoke a compiled String serializer. Unsupported combinations have no
constructor, and unknown form tags fail native metadata decoding.

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
and a 15-second deadline gives an explicit retry path. Input changes terminate
current work and clear the old result. Generation and request identities suppress stale
results. Duplicate submissions are disabled while loading/running; page navigation
disposes each owner. Resource and runtime errors are displayed as text, and failure never
automatically replays the previous call.

Natural inputs use validated decimal text. VIR returns nonnegative JavaScript
`BigInt` values; the worker formats exact decimal display text before posting the
result. No conversion to JavaScript `Number` occurs. Reject negatives, whitespace, decimals, exponent notation,
and non-digits before invoking. Limits are 4,096 UTF-16 code units for a String input, 256
digits for a Nat input, and 65,536 UTF-16 code units for displayed output. These are
input/output bounds, not a Wasm heap budget. Stop provides actual interruption; execution
of trusted compiled code can allocate memory before an output limit is checked. Arbitrary
Lean evaluation, custom foreign-function providers, browser IO/DOM/React exports, tactics,
and general dependent interfaces are outside this milestone.

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
