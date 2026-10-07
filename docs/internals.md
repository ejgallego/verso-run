# How verso-run fits together

## Common machinery and Manual integration

The common modules have no dependency on `VersoManual`: `Model` retains portable
experiment data, `Callable` classifies entries and builds expected contracts,
`Anchored` reuses standard checked source anchors, `Render` builds the console,
`Collect` walks a genre's AST with its extension decoder, and `Publication`
prepares the complete validated file inventory without writing it.

`Manual` supplies inline scope handling and a Run wrapper with native highlighted
source children. `Publish` decodes Manual wrappers and writes the common plan into
the selected HTML layout. Public imports remain `VersoLeanRun` and
`VersoLeanRun.Publish`. The [genre review](multi-genre.md) describes the remaining
Blog and Slides work; only Manual is currently supported.

## Resource ownership and site integration

Follow VIR's stock resource workflow, demonstrated by the
[lakefile](../lakefile.lean) and [carrier](../resources/LeanRunGate/Resources.lean):

1. Register the chapter or helper as a program library. Its public marked
   declarations supply root entrypoints; imports supply their compiled dependency
   closure. A declaration in an imported module needs its own registered program
   bundle when called directly.
2. Register a disjoint resource carrier library with a `:virResourcePack`
   prerequisite, and name the owner/module pair in the package's typed target:

   ```lean
   target virPrograms (_pkg) : Array (Lean.Name × Lean.Name) := do
     return Job.pure #[(`MyResources, `MyChapter)]
   ```

   The demo also registers `LeanRunHelperResources` / `LeanRunGate.Helper` for
   its anchored entry. There are no JSON recipes, callable role aliases, or
   handwritten interface IDs. Keep program and carrier libraries disjoint.
3. Embed the prepared bundle by its owning library name. The chapter imports
   extension support, never its carrier:

   ```lean
   module
   public import Vir.Resources.Embed

   public def MySite.program : Vir.Resources.Bundle :=
     include_vir_library MyResources
   ```

   The literal Lake library key and prerequisite survive custom source/build
   directories; no generated-path changes are needed.
4. Import the chapter, carrier, and `VersoLeanRun.Publish` in the native generator:

   ```lean
   def main := manualMain (%doc MyChapter)
     (extraSteps := [VersoLeanRun.publish #[MySite.program]])
   ```

   Pass every required producer bundle. The publisher uses VIR's locked runtime
   by default; a compatible explicit runtime may use the named `runtime` argument.

The graph remains support → chapter/helper → program preparation → carrier →
native generator. No per-block packaging or second execution compiler is added.
Verso's standard external-code path prepares cached highlighting separately.

`Experiment.program` identifies the document placement group and diagnostic
position. `producerModule`, resolved from Lean's declaration ownership after any
HTML adaptation, identifies the executable producer. Local HTML adapters belong
to the document module; imported anchored entries belong to their producer.
The publisher matches this module to the generated bundle's `logicalId` and
preserves the original index-to-manifest mapping. Identical bundles deduplicate.
Distinct bundles with one logical ID fail `ResourceSet.forSite` validation with
`LOGICAL_ID_CONFLICT`, before per-form binding or output writes.

Publication validates resources, module availability, and independent expectation
construction. VIR's `createProgram` validates actual root declarations and their
signatures before runtime instantiation. `forSite` does not check callable types;
there is no embedded-interface parser or reopening of producer files here.

VIR's `analyzeExportInterface` supplies each independently elaborated signature,
with canonical type descriptors and effect. The publisher places that exact
`{args, result, effect}` object in `expectedExport`; the worker uses the full
Lean declaration as both expectation key and call name. A missing expectation
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
synchronous execution; another Run creates a fresh instance. Input changes terminate
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
| Lean | 4.34.0 (`293d5d0c0c3f3dded4688b3ccd6a33939ac5102b`) |
| Verso | `3f6366aa8045b342b0b68c0373a8ebfce7d5611f` |
| VIR | `bda79d5c4ab7d061c971fcd8917f536393ec03ee` (a PR #217 snapshot) |
| Illuminate | `a1a61c9678da010e958ed24cdfa6f635b85f172a` |
| Runtime | `e415e41a43eccf298b710056efccf6c3d436d5fceb4e130fb06cb09d12d027dd` |

The minimal Verso fork is based on release `cad4b633` and exposes the existing
`toHighlightedLeanBlock` helper; it contains no demo code. The runtime uses VIR
compatibility version 3 (resource descriptor version 2). Lake acquires and verifies VIR's locked runtime, so
authors do not need a separate SDK installation or Wasm build.


The selected public pair is VIR PR #217 commit `bda79d5c` and runtime `e415…`,
pack SHA256 `3910c29e40ee68c3b110355fa1d30dae3029f2b34967269642521fc8409848d7`.
Lean, Verso, and Illuminate retain their previous exact pins. Producer CI status
belongs to the VIR Module owner; consumer acceptance is recorded separately in
[validation](validation.md).
