# Compiled Lean Run for Manual

This optional package adds a first Run form to Verso Manual. Lean elaborates and compiles the displayed declarations during the document build. A dedicated browser worker calls those retained declarations through VIR's public resource API. Readers edit inputs, not Lean source.

The package stays on Verso release `cad4b633` and Lean **4.34.0**, with VIR pinned to `e92d95db62b14db88669394791f6f981161d5674`. It does not migrate current Verso main's toolchain. The matching runtime is content ID `832ab095ad79df0f10f538bcf71272731bb74b90df44f965dac2f086c222897d`; its compatibility binds Lean source revision `293d5d0c0c3f3dded4688b3ccd6a33939ac5102b` and VIR compatibility version 1. Lake acquires and verifies the runtime selected by VIR's lock; no separate SDK installation or Wasm build is required.

## Build, generate, serve, test

Run these commands from `experiments/lean-run` in this feature worktree:

```sh
lake build
lake exe lean-run-demo --with-html-single --with-tex --depth 2
python3 -m http.server 8794 --directory _out/html-multi
```

Open <http://127.0.0.1:8794/Greeting/>. Single-page output is in `_out/html-single`, and the TeX fallback is `_out/tex/main.tex`. Copy either complete HTML directory to any HTTP hosting directory, including a nested deployment prefix. The site includes all runtime, program, manifests, host code, highlighting, and license files. No checkout, runtime CDN, or reader-side Lean installation is needed.

The optional package's test driver uses the repository's Python/Playwright browser tooling. Install `uv` and a Chromium browser first. Tests use installed `google-chrome` when available, otherwise Playwright's installed Chromium:

```sh
lake test -- --mutations
```

This builds the native generator/oracle, generates both HTML layouts and TeX, runs negative author fixtures, and executes the real program in Chromium. `--mutations` additionally changes the greeting body and a reached helper body, rebuilds and compares browser results to the native oracle, and restores source and program identity in `finally`. Evidence defaults to `/tmp/verso-lean-run-acceptance`; `--output PATH` selects another directory. Root repository regression commands remain `lake build` and `lake test` from the feature worktree root.

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

`entry` is mandatory and resolves through Lean's actual declaration identity and the retained example scopes. The selected declaration must carry `@[vir_export]`. VIR classifies its interface; this form admits only pure, monomorphic `String → String` and `Nat → Nat`, each with one explicit argument. Missing, unmarked, private, unsupported, non-executable, and unavailable standard-runtime dependencies have negative tests. Other block arguments, including `-keep` and `+error`, are rejected. Ordinary `lean` blocks retain their existing behavior.

`leanRun` uses ordinary command elaboration and the shared highlighted-block constructor, retaining source locations, hovers, and example links. The only core Verso change exposes `toHighlightedLeanBlock` for this reuse. The extension support lives in this optional package because Verso's package-wide native precompilation attempts to compile VIR's browser extern symbols as C when VIR is added directly to that package.

Repeated placements may select the same declaration, for example with `#check Demo.greet` as the displayed code. Each rendered placement has a distinct instance ID and its own worker/runtime.

## Resource ownership and site integration

Follow VIR's public resource workflow, as demonstrated by this package's lakefile, `vir-resources/LeanRunGateResources.json`, and `resources/LeanRunGate/Resources.lean`:

1. Register the module chapter as a program library. Its marked declarations are the executable roots; the ordinary compiled-module producer acquires their dependency closure.
2. Register a separate carrier library with a `:virResourcePack` prerequisite and a recipe naming the chapter module and selected roles/declarations. Use `verso-string-string-v1` or `verso-nat-nat-v1` as the corresponding recipe interface ID.
3. Embed the prepared bundle with `include_vir_bundle` in the carrier. The chapter imports extension support, never its carrier.
4. In the native generator, import the carrier, `Vir.Resources.Runtime`, and `VersoLeanRun.Publish`. Supply `VersoLeanRun.publish runtimeBundle #[("Actual.Chapter.Module", programBundle)]` as an extra step to `manualMain`.

The resulting graph is extension support → chapter/helper → compiled program preparation → carrier → native generator. Resource preparation is a normal Lake dependency. Neither per-block packaging nor a second frontend pass is used. The publisher validates every rendered experiment against its owning program and recipe, with module/line/column provenance, before writing execution assets. It embeds UI support files in the native executable as well as program/runtime bytes. It runs outside the checkout without reading producer files; the existing Verso generator still requires a `lean-toolchain` project marker in its working directory or a parent.

The worker adapter independently requires the selected declaration, recipe ID, pure effect, and reviewed scalar ABI descriptor when creating a program. It never derives its expectation from downloaded program metadata. An interface ID alone does not establish the type or semantics; native/browser oracle checks supply the demonstrated semantic evidence.

## Interaction and limits

Execution resources load only on first Run. Separate activated forms have independent execution state. Stop terminates the dedicated worker, including pending creation or synchronous execution; another Run creates a fresh instance. Input changes terminate current work and clear the old result. Generation and request identities suppress stale results. Duplicate submissions are disabled while loading/running; page navigation disposes each owner. Resource and runtime errors are displayed as text, and failure never automatically replays the previous call.

Natural inputs use exact decimal text throughout VIR's documented boundary; no conversion to JavaScript `Number` occurs. Reject negatives, whitespace, decimals, exponent notation, and non-digits before invoking. Limits are 4,096 UTF-16 code units for a String input, 256 digits for a Nat input, and 65,536 UTF-16 code units for displayed output. These are input/output bounds, not a Wasm heap budget. Stop provides actual interruption; execution of trusted compiled code can allocate memory before an output limit is checked. Arbitrary Lean evaluation, custom foreign-function providers, browser IO/DOM/React exports, tactics, and general dependent interfaces are outside this milestone.

Forms have labels, keyboard submission, accessible status updates, escaped text output, and disabled controls until enhancement. Source remains available without JavaScript, and TeX renders the same highlighted source without interactive controls.

## Retained evidence

`evidence/results.json` records the 25 final acceptance checks and exact publication identities; `evidence/manual.png` is a browser capture. `evidence/worker-gate.json` retains the independent public API create/call/dispose/recreate gate, and `evidence/validation.txt` records root regression results. The browser checks cover edited inputs, Unicode, exact integers above JavaScript's safe range, repeated placements, real long-running interruption, pending-load cancellation, ignored stale outcomes, missing resources with explicit recovery, root/nested copied publication, disabled JavaScript, TeX, body/helper invalidation, and restored identity. Screenshots supplement those execution checks.

Browser execution is qualified here in Chromium. Firefox, Safari, mobile layouts, and assistive-technology audits were not exercised. The cached-page lifecycle handler is checked with a persisted `PageTransitionEvent`; actual back-cache restoration across browsers remains unqualified. Porting to current Verso main's Lean 4.35.0-rc3 requires a compatible VIR/runtime release and is not included.
