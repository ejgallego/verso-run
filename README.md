# verso-vir

verso-vir provides compiled Run forms for Verso Manual. Lean elaborates and compiles the displayed declarations during the document build. A dedicated browser worker calls those retained declarations through VIR's public resource API. Readers edit inputs, not Lean source.

The package uses Lean **4.34.0** and a minimal Verso fork revision `3f6366aa8045b342b0b68c0373a8ebfce7d5611f` based on release `cad4b633`. That fork exposes the existing `toHighlightedLeanBlock` helper; it contains no demo code. VIR is pinned to [PR #217](https://github.com/ejgallego/lean-vir/pull/217) head `1ed079ca2ab8306ae877ed4920f7d55d392365f8`. It does not migrate current Verso main's toolchain. The matching runtime is content ID `832ab095ad79df0f10f538bcf71272731bb74b90df44f965dac2f086c222897d`; its compatibility binds Lean source revision `293d5d0c0c3f3dded4688b3ccd6a33939ac5102b` and VIR compatibility version 1. Lake acquires and verifies the runtime selected by VIR's lock; no separate SDK installation or Wasm build is required.

## Build, generate, serve, test

Install [elan](https://github.com/leanprover/elan), [uv](https://docs.astral.sh/uv/), and a Chromium browser for tests. Lean is selected by `lean-toolchain`. Then run these commands:

```sh
git clone https://github.com/ejgallego/verso-vir.git
cd verso-vir
lake build
lake exe lean-run-demo --with-html-single --with-tex --depth 2
python3 -m http.server 8794 --directory _out/html-multi
```

Open <http://127.0.0.1:8794/Greeting/>. Single-page output is in `_out/html-single`, and the TeX fallback is `_out/tex/main.tex`. Copy either complete HTML directory to any HTTP hosting directory, including a nested deployment prefix. The site includes all runtime, program, manifests, host code, highlighting, and license files. No checkout, runtime CDN, or reader-side Lean installation is needed.

For the longer internal-demo example, open <http://127.0.0.1:8794/Stack-calculator/>. It implements a small typed instruction language, parser, stack evaluator, and execution trace in the displayed Lean code. Run the supplied `6 7 * 2 +` program, then try `5 dup *`, `2 3 swap dup * +`, or `9007199254740993 2 *`. An empty program, unknown instruction, or stack underflow returns a readable explanation. The demo bounds programs to 32 instructions, stacks to 16 values, and numbers to 80 decimal digits, including intermediate results.

After generating the site, run `python3 scripts/package-demo.py` to create a complete copy at `_out/verso-vir-demo.zip`. Unpack it, then run `python3 -m http.server 8794 --directory verso-vir-demo` and open `/Stack-calculator/`, `/HTML-greeting/`, or `/Illuminate-diagrams/`. The recipient needs no Lean installation.

Open <http://127.0.0.1:8794/HTML-greeting/> for a small HTML example. Its Lean function returns Verso’s `Html` type for a styled greeting card. The block generates a scalar export using `Html.asString` and selects the HTML preview automatically. Verso’s HTML syntax escapes interpolated names.

Open <http://127.0.0.1:8794/Illuminate-diagrams/> for the library example. Enter a node count from 1 to 8 and Run: Lean positions numbered circles and links, builds Illuminate drawing commands, and renders SVG through `Illuminate.Svg.render`. The browser only displays the returned markup. Invalid counts produce a helpful message. The displayed function returns `Verso.Output.Html` and uses the existing generated scalar adapter.

Illuminate is pinned to `a1a61c9678da010e958ed24cdfa6f635b85f172a`, the same Lean 4.34.0 revision used by this Verso release. The example uses its public `DrawCmd`, `PathData`, `Matrix`, style, and SVG APIs. Layout coordinates and the view box are computed in the example. It is qualified for this drawing-command path; general `Diagram.renderDiagram` and `Diagram.compile` still reach float operations absent from the locked VIR runtime. Reproducible author fixtures and details are in [`evidence/illuminate-gates.md`](evidence/illuminate-gates.md).

The test driver uses uv and Playwright. Tests use installed `google-chrome` when available, otherwise Playwright's Chromium. Install the latter with `uv run --with playwright playwright install chromium`:

```sh
lake test -- --mutations
```

This builds the native generator/oracle, generates both HTML layouts and TeX, checks missing and duplicate bundle registration, runs negative author fixtures, and executes the real program in Chromium. `--mutations` additionally changes the greeting body and a reached helper body, checks ambiguous recipe roles, relocates the carrier source/build directories without editing its library-key include, and restores sources and program identity in `finally`. Evidence defaults to `/tmp/verso-lean-run-acceptance`; `--output PATH` selects another directory. Run builds and mutation tests sequentially. Mutation tests temporarily edit sources and restore them in `finally`. The independent Verso hook has its own upstream build/test validation.

The smaller worker gate can be repeated independently:

```sh
lake exe lean-run-gate /tmp/verso-lean-run-gate-site
uv run --with playwright python tests/worker-gate.py
```

## Authoring

Import `VersoLeanRun` into a module chapter and disable postponed compilation for executable examples:

````lean
module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "My runnable chapter" =>

```leanRun (entry := Demo.greet)
@[vir_export]
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name
```
````

`entry` is mandatory and resolves through Lean's actual declaration identity and the retained example scopes. Scalar declarations must carry `@[vir_export]`. VIR classifies their interfaces; this form admits pure, monomorphic `String → String` and `Nat → Nat`, each with one explicit argument. A public `String → Verso.Output.Html` function is adapted automatically, without an author-side `@[vir_export]` marker. Missing, unmarked, private, unsupported, non-executable, and unavailable standard-runtime dependencies have negative tests. Other block arguments, including `-keep` and `+error`, are rejected. Ordinary `lean` blocks retain their existing behavior.

The optional `(input := "...")` argument supplies the form's initial text, without running it on page load. For example, the stack calculator uses `(input := "6 7 * 2 +")`. Readers can edit or clear it normally, and ordinary input validation still applies when they run it.

For a longer example, `+collapsed` puts its source in a native expandable “View Lean implementation” panel. It starts closed so the input is easy to reach; readers can open it with a mouse or keyboard, including without JavaScript. The source remains fully present in HTML and TeX, and all declarations are still elaborated and retained normally.

Scalar output defaults to plain text. `(output := "html")` requires a String result and displays the markup in an isolated, sandboxed frame. Typed HTML entries select this mode automatically; explicit `output := "text"` is rejected. This preview supports static HTML, inline CSS, and data images; scripts and external embedded resources are disabled. String functions interpolating reader input into markup should escape it for the chosen context. Typed HTML functions can use Verso’s HTML syntax to escape text and attributes automatically; raw HTML nodes remain an explicit author choice. Input edits, Stop, pending calls and failures clear the previous preview. Runtime errors remain plain text, and the result-size limit still applies. The frame has a fixed height with scrolling for larger documents.

For a typed HTML entry, the block generates a public `String → String` wrapper named
`<entry>.leanRunHtml`, calling `Verso.Output.Html.asString`. Select this wrapper in the
VIR recipe, while the block's `entry` stays the original function:

````lean
```leanRun (entry := Demo.card) (input := "Ada")
open Verso.Output.Html
public def Demo.card (name : String) : Verso.Output.Html :=
  {{ <h2> "Hello, " {{name}} "!" </h2> }}
```
````

```json
{ "role": "card", "declaration": "Demo.card.leanRunHtml",
  "interfaceId": "verso-string-string-v1" }
```

The generated wrapper receives the usual `vir_export` validation, including its
compiled dependency closure. Repeated placements reuse it; conflicting declarations
at that name produce an author diagnostic. Neither VIR's ABI nor the renderer changes.

`leanRun` uses ordinary command elaboration and the shared highlighted-block constructor, retaining source locations, hovers, and example links. The only core Verso change exposes `toHighlightedLeanBlock` for this reuse. This standalone package leaves native precompilation disabled pending the separate VIR native-client fix. It uses the normal Verso package as a Git dependency.

Repeated placements may select the same declaration, for example with `#check Demo.greet` as the displayed code. Each rendered placement has a distinct instance ID and its own worker/runtime.

## Resource ownership and site integration

Follow VIR's public resource workflow, as demonstrated by this package's lakefile, `vir-resources/LeanRunGateResources.json`, and `resources/LeanRunGate/Resources.lean`:

1. Register the module chapter as a program library. Its marked declarations are the executable roots; the ordinary compiled-module producer acquires their dependency closure.
2. Register a separate carrier library with a `:virResourcePack` prerequisite and a recipe naming the chapter module and selected roles/declarations. Use `verso-string-string-v1` or `verso-nat-nat-v1` as the corresponding recipe interface ID.
3. Embed the prepared bundle by its owning library name. The chapter imports extension support, never its carrier:

   ```lean
   module
   public import Vir.Resources.Embed

   public def MySite.program : Vir.Resources.Bundle :=
     include_vir_library MyResources
   ```

   `MyResources` is the literal Lake library name from step 2. Custom source/build directories require no generated-path changes; the library's prerequisite prepares the pack before elaboration.

4. In the native generator, import the chapter, carrier, and `VersoLeanRun.Publish`, then register the embedded bundles:

   ```lean
   def main := manualMain (%doc MyChapter)
     (extraSteps := [VersoLeanRun.publish #[MySite.program]])
   ```

   The publisher uses VIR's locked runtime by default. A resource set with several chapters uses the same call with several bundles. No runtime import or module-to-bundle mapping is needed. An application supplying its own compatible runtime can use the named `runtime` argument.

The resulting graph is extension support → chapter/helper → compiled program preparation → carrier → native generator. Resource preparation is a normal Lake dependency. Neither per-block packaging nor a second frontend pass is used. The publisher binds each form's actual declaration to an export role in the supplied bundles and checks the interface ID, with module/line/column provenance, before writing execution assets. Missing exports or multiple matching recipe roles produce errors; repeated references to an identical bundle are deduplicated. Keep each runnable declaration in one supplied recipe role. VIR's `ResourceSet.forSite` owns bundle validation, deduplication, complete file inventory, manifest envelopes, and loader paths. Verso writes that inventory through its normal output step and adds the form bindings and worker UI files.

The native executable embeds UI support files as well as program/runtime bytes. It runs outside the checkout without reading producer files; the existing Verso generator still requires a `lean-toolchain` project marker in its working directory or a parent. VIR still requires the library registration and JSON recipe from steps 1–2; this integration adds no alternative recipe format or Lake DSL. The demo retains `compiler.postponeCompile false` pending discussion with the compiler maintainer.

During document elaboration, VIR's `analyzeExportInterface` classifies the selected declaration. Its canonical `InterfaceType.toJson` encoder supplies the argument and result descriptors, including ABI tags; VIR also supplies the effect label. The compiled document retains this serialized signature. The native publisher combines it with the recipe's declaration and interface ID in `publication.json`, and the worker passes that `expectedExport` directly to VIR's existing `expectedExports` checker. The JavaScript adapter owns input and display policy; it no longer reconstructs ABI descriptors from the form's shape.

The expectation comes from the trusted document build, independently of the program fetched at runtime. A missing published expectation fails before worker creation, and VIR rejects argument, result, arity, and effect disagreements before invocation. An interface ID alone does not establish the type or semantics; native/browser oracle checks supply the demonstrated semantic evidence.

## Interaction and limits

Execution resources load only on first Run. Separate activated forms have independent execution state. Stop terminates the dedicated worker, including pending creation or synchronous execution; another Run creates a fresh instance. Input changes terminate current work and clear the old result. Generation and request identities suppress stale results. Duplicate submissions are disabled while loading/running; page navigation disposes each owner. Resource and runtime errors are displayed as text, and failure never automatically replays the previous call.

Natural inputs use exact decimal text throughout VIR's documented boundary; no conversion to JavaScript `Number` occurs. Reject negatives, whitespace, decimals, exponent notation, and non-digits before invoking. Limits are 4,096 UTF-16 code units for a String input, 256 digits for a Nat input, and 65,536 UTF-16 code units for displayed output. These are input/output bounds, not a Wasm heap budget. Stop provides actual interruption; execution of trusted compiled code can allocate memory before an output limit is checked. Arbitrary Lean evaluation, custom foreign-function providers, browser IO/DOM/React exports, tactics, and general dependent interfaces are outside this milestone.

Forms group the highlighted source above a quiet input/result area, with aligned controls, visible keyboard focus, and wrapping on narrow screens. They have labels, keyboard submission, accessible status updates, escaped text output, and disabled controls until enhancement. Source remains available without JavaScript, and TeX renders the same highlighted source without interactive controls.

## Retained evidence

`evidence/results.json` records the 55 final acceptance checks and exact publication identities; `evidence/manual.png` is a browser capture. `evidence/worker-gate.json` retains the independent public API create/call/dispose/recreate gate, and `evidence/validation.txt` records root regression results. The browser checks cover edited inputs, Unicode, exact integers above JavaScript's safe range, repeated placements, real long-running interruption, pending-load cancellation, ignored stale outcomes, missing resources with explicit recovery, root/nested copied publication, disabled JavaScript, TeX, body/helper invalidation, restored identity, compiler-signature publication in both layouts and native-only generation, rejection of mismatched or missing expectations before invocation, duplicate/missing/ambiguous registration, and carrier relocation across source/build roots with unchanged publication. Screenshots supplement those execution checks. `evidence/design-results.json` records the 30 non-mutation interaction checks repeated after the visual refinement; `design-desktop.png`, `design-mobile.png`, and the other `design-*.png` captures show the final layout. Chromium reviews cover 1280px, 390px, and 320px widths, keyboard submission/focus, long exact-Nat wrapping, narrow-screen search, and the JavaScript-disabled fallback. The 55-check campaign in `results.json` additionally covers the calculator preset/trace, arithmetic, errors, bounds, source disclosure, typed HTML adapter reuse and collision checks, non-executable/private entry rejection, HTML preview/native markup agreement, escaped input, isolation, cleanup, failure recovery, and Illuminate native/browser markup, drawing geometry, count bounds, and copied deployments. `illuminate-*.png` captures the new diagram on desktop and mobile. `calculator-*.png` captures the longer example with its source panel closed and open.

Browser execution is qualified here in Chromium. Firefox, Safari, physical mobile devices, and assistive-technology audits were not exercised. The cached-page lifecycle handler is checked with a persisted `PageTransitionEvent`; actual back-cache restoration across browsers remains unqualified. Moving to a newer Lean line requires compatible Verso, VIR, and runtime pins and is not part of this initial extraction.

## Repository history

This repository extracts the prototype previously developed in
`experiments/lean-run` on Verso's local `feat/lean-run` branch. Its eight
development commits are preserved with paths moved to the repository root.
The extraction source is Verso commit `06860e5e`; original evidence is retained.
The Verso dependency isolates the one-line highlighting hook from that prototype.

Use `VersoLeanRun` and `VersoLeanRun.Publish` as the library imports. The Lean
package is named `verso_vir`; the existing module and executable names are retained.
Library support lives under `support/`, browser support under `web/`, and demo
code under `gates/` and `resources/`. Illuminate code belongs to the examples.

See [LICENSE](LICENSE) for the Apache-2.0 license and [AGENTS.md](AGENTS.md) for
contributor notes. GitHub CI builds from the exact dependency pins and runs all
acceptance/mutation checks, retaining the generated site and test evidence.
