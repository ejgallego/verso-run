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

Follow VIR's public resource workflow, as demonstrated by the
[lakefile](../lakefile.lean), [resource
recipe](../vir-resources/LeanRunGateResources.json), and [carrier
module](../resources/LeanRunGate/Resources.lean):

1. Register the module chapter as a program library. Its marked declarations are the executable roots; the ordinary compiled-module producer acquires their dependency closure.
2. Register a separate carrier library with a `:virResourcePack` prerequisite and a recipe naming the chapter module and selected roles/declarations. Use `verso-string-string-v1` or `verso-nat-nat-v1` as the corresponding recipe interface ID.
3. Embed the prepared bundle by its owning library name. The chapter imports extension support, never its carrier:

   ```lean
   module
   public import Vir.Resources.Embed

   public def MySite.program : Vir.Resources.Bundle :=
     include_vir_library MyResources
   ```

   `MyResources` is the literal Lake library name from step 2. Custom source/build
directories require no generated-path changes; the library's prerequisite prepares the
pack before elaboration.

4. In the native generator, import the chapter, carrier, and `VersoLeanRun.Publish`, then register the embedded bundles:

   ```lean
   def main := manualMain (%doc MyChapter)
     (extraSteps := [VersoLeanRun.publish #[MySite.program]])
   ```

   The publisher uses VIR's locked runtime by default. A resource set with several
chapters uses the same call with several bundles. No runtime import or module-to-bundle
mapping is needed. An application supplying its own compatible runtime can use the named
`runtime` argument.

The resulting graph is extension support → chapter/helper → compiled program preparation →
carrier → native generator. Resource preparation is a normal Lake dependency. Neither
per-block packaging nor a second frontend pass is used. The publisher binds each form's
actual declaration to an export role in the supplied bundles and checks the interface ID,
with module/line/column provenance, before writing execution assets. Missing exports or
multiple matching recipe roles produce errors; repeated references to an identical bundle
are deduplicated. Keep each runnable declaration in one supplied recipe role. VIR's
`ResourceSet.forSite` owns bundle validation, deduplication, complete file inventory,
manifest envelopes, and loader paths. Verso writes that inventory through its normal
output step and adds the form bindings and worker UI files.

The native executable embeds UI support files as well as program/runtime bytes. It runs
outside the checkout without reading producer files; the existing Verso generator still
requires a `lean-toolchain` project marker in its working directory or a parent. VIR still
requires the library registration and JSON recipe from steps 1–2; this integration adds no
alternative recipe format or Lake DSL. The demo retains `compiler.postponeCompile false`
pending discussion with the compiler maintainer.

During document elaboration, VIR's `analyzeExportInterface` classifies the selected
declaration. Its canonical `InterfaceType.toJson` encoder supplies the argument and result
descriptors, including ABI tags; VIR also supplies the effect label. The compiled document
retains this serialized signature. The native publisher combines it with the recipe's
declaration and interface ID in `publication.json`, and the worker passes that
`expectedExport` directly to VIR's existing `expectedExports` checker. The JavaScript
adapter owns input and display policy; it no longer reconstructs ABI descriptors from the
form's shape.

The expectation comes from the trusted document build, independently of the program
fetched at runtime. A missing published expectation fails before worker creation, and VIR
rejects argument, result, arity, and effect disagreements before invocation. An interface
ID alone does not establish the type or semantics; native/browser oracle checks supply the
demonstrated semantic evidence.

## Interaction and limits

Execution resources load only on first Run. Separate activated forms have independent
execution state. Stop terminates the dedicated worker, including pending creation or
synchronous execution; another Run creates a fresh instance. Input changes terminate
current work and clear the old result. Generation and request identities suppress stale
results. Duplicate submissions are disabled while loading/running; page navigation
disposes each owner. Resource and runtime errors are displayed as text, and failure never
automatically replays the previous call.

Natural inputs use exact decimal text throughout VIR's documented boundary; no conversion
to JavaScript `Number` occurs. Reject negatives, whitespace, decimals, exponent notation,
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
| VIR | `1ed079ca2ab8306ae877ed4920f7d55d392365f8` (a PR #217 snapshot) |
| Illuminate | `a1a61c9678da010e958ed24cdfa6f635b85f172a` |
| Runtime | `832ab095ad79df0f10f538bcf71272731bb74b90df44f965dac2f086c222897d` |

The minimal Verso fork is based on release `cad4b633` and exposes the existing
`toHighlightedLeanBlock` helper; it contains no demo code. The runtime uses VIR
compatibility version 1. Lake acquires and verifies VIR's locked runtime, so
authors do not need a separate SDK installation or Wasm build.


These pins remain frozen while VIR prepares a public successor. Adoption includes
new resource registration, export lookup, and numeric transport; it is a separate
integration task. See [the roadmap](../ROADMAP.md).
