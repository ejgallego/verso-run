# Authoring runnable examples

A Run block selects a function with `entry`. Its Lean type chooses the input
control and result display. The document build handles VIR registration.

## A basic block

Start with a function defined inside a `leanRun` block for a small, self-contained
example. The same block works in Manual, Blog Page/Post and Slides. Select the
genre adapter import, open its namespace, and keep compilation enabled. For a
Manual chapter:

````lean
module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "My runnable chapter" =>

```leanRun (entry := Demo.greet) (input := "Ada")
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name
```
````

The function must be public, executable, pure and monomorphic. No
`@[vir_export]` attribute is required: `entry` selects and registers the callable
using VIR's existing validator, including its compiled dependencies. Existing
explicit attributes continue to work. Helpers are compiled as dependencies;
they do not become entrypoints merely because they appear in the block.

`entry` resolves through Lean's actual declaration identity and the retained
example scopes. Repeated blocks can select the same function, for example with
`#check Demo.greet` as displayed code. Each placement has its own worker.
Ordinary `lean` blocks keep their existing behavior. `-keep`, `+error` and unknown
Run arguments are rejected.

## Choose where the code lives

| Goal | Authoring choice |
| --- | --- |
| Write a self-contained example | Define the function inside `leanRun`. |
| Reuse a function from a Lean module | Import the module and select the function with `leanRun`; display a reference such as `#check`. |
| Explain an existing library implementation | Use `leanRunAnchor` to display a checked quotation of its source region. |

Both Run block forms use the same execution and publication workflow. Anchors
add source-display checks; use them when the implementation itself belongs in
the explanation.

## Arguments and defaults

| Argument | Meaning | Default |
| --- | --- | --- |
| `(entry := My.function)` | Select the function | Required |
| `(input := "...")` | Initial reader input; does not run on page load | Empty String, `"0"` for Nat/UInt64, `"false"` for Bool |
| `+multiline` | A textarea for a String argument | Off |
| `+collapsed` | Initially folded source | Off |

Bool gets a true/false selector. Boolean presets are the literal strings
`"true"` or `"false"`. Nat and UInt64 get exact decimal inputs; UInt64 is bounded
by `18446744073709551615` and arithmetic uses Lean's normal wraparound. Values
beyond JavaScript's safe integer range remain exact.

`+multiline` keeps whitespace and blank lines. Enter edits text; Ctrl+Enter or
⌘+Enter runs the function. Numeric and Boolean entries reject it. String input
has a 4096 UTF-16 code unit bound; all results have the common output bound.

`+collapsed` puts source in an expandable “View Lean implementation” panel.
Source remains present in HTML and Manual TeX, including without JavaScript.

## The result type chooses the display

| Function type | Result display |
| --- | --- |
| `String → String`, `Nat → Nat`, `Bool → Bool`, `UInt64 → UInt64` | Plain text |
| `String`, `Nat`, `Bool`, or `UInt64` → `Verso.Output.Html` | An isolated HTML preview |
| `String`, `Nat`, `Bool`, or `UInt64` → `VersoLeanRun.SequenceView` | Labelled states with selection and scrubbing |

A String containing markup is still plain text. There is no `output` block
argument. Return `Html` when the result is intended to be rendered as HTML:

````lean
```leanRun (entry := Demo.card) (input := "Ada")
open Verso.Output.Html
public def Demo.card (name : String) : Verso.Output.Html :=
  {{ <h2> "Hello, " {{name}} "!" </h2> }}
```
````

Verso's typed HTML syntax escapes interpolated text and attributes. Raw HTML
nodes remain an explicit author choice. The preview supports static HTML, inline
CSS and data images; scripts and external embedded resources are disabled.
Input edits, Stop, pending calls and failures clear the preview. Errors stay
plain text; the frame scrolls larger results.

The extension generates a typed transport adapter for VIR. Authors select the original
Html function. Repeated placements reuse the serializer; a conflicting declaration
at its generated name causes an author error.

## Reuse a function from an imported module

Keep shared functions in ordinary Lean modules. For example,
`Examples/Arithmetic.lean` can contain:

```lean
module
public def Examples.twice (n : Nat) : Nat := n + n
```

Import the module into your document and select its function with `leanRun`:

````lean
module
public import VersoLeanRun
import Examples.Arithmetic
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "Shared arithmetic" =>

```leanRun (entry := Examples.twice) (input := "21")
#check Examples.twice
```
````

The form runs the imported function; its source panel shows the `#check`
reference. The same approach works with the Blog and Slides adapter imports.
Several documents can reuse one implementation without adding source markers or
quoting its body.

The document creates a callable adapter around the imported function and includes
its compiled dependencies. Register and publish the **document module's** resource
bundle, as for inline definitions. The producer needs no VIR export marker or
separate root bundle. Supported scalar and rendered result types use the same
controls and views as inline definitions.

## Run an anchored example from an imported module

Use `leanRunAnchor` for a walkthrough that should display the imported
implementation itself. It checks that the selected function is defined in the
quoted region and that the quotation matches the producer's source. Add standard
Verso source markers around the region in `Examples/Arithmetic.lean`:

```lean
module
-- ANCHOR: twice
public def Examples.twice (n : Nat) : Nat := n + n
-- ANCHOR_END: twice
```

Import the producer into the document. Verso's existing project/module defaults
can shorten repeated blocks:

````lean
import Examples.Arithmetic
set_option verso.exampleProject "."
set_option verso.exampleModule "Examples.Arithmetic"

```leanRunAnchor twice (entry := Examples.twice) (input := "21")
public def Examples.twice (n : Nat) : Nat := n + n
```
````

Explicit `(project := ".")` and `(module := Examples.Arithmetic)` arguments remain
available. The entry must be defined in the selected anchor, public and executable.
The body must match the source region; stale or empty bodies get Verso's normal
replacement/fill-in suggestions. Anchor comments are omitted from the display.

Keep the quoted body in the document. When the implementation changes, a stale
quotation fails the build until you update it; the replacement suggestion supplies
the current source. This checks documentation drift while keeping the example
readable in the document's own source file. A region can contain several
declarations, and `entry` selects the one to run.

Anchored calls use the same imported-function adapters and document-owned resource
bundles described above. Checked runnable anchors currently require the producer
to belong to the document's own project.

Input, `+multiline` and `+collapsed` work across Manual, Blog and Slides. Standard
source options such as `-showProofStates` and `-defSite` remain available. Open
`Verso.Code.External` for the ordinary `anchor` block. Use `-defSite` on repeated
Manual displays when another block already owns the desired definition target.
An ordinary `anchor` can show the same source without a Run form.

`leanRun` defines or reuses a function directly in any of the three genres.
Namespace, open declarations and definitions remain available in later Run blocks.
`leanRunAnchor` is optional when the document needs a checked source quotation.
Each genre retains native source styling and links. See
[Blog authoring](blog.md) and [Slides authoring](slides.md).

## Project wiring and migration

Keep support → producer → document → resource preparation → carrier → generator
acyclic. The native generator imports the document and its separate resource
carrier; the document imports support and its source producers, never its carrier.
See [resource integration](internals.md#resource-ownership-and-site-integration).
Retain `compiler.postponeCompile false`; native precompilation remains deferred.

When updating an older example, remove redundant `@[vir_export]` markers and
`output` options. Change a String HTML serialization wrapper to return typed
`Html` directly. For anchors, move root resource registration from the imported
producer to the document module. The independently pinned
[Manual starter](../examples/manual-starter/README.md) demonstrates entry-selected
text and Html functions without explicit export annotations. Its cold Git test
qualifies that published dependency revision separately from this checkout.
New generators should pass the complete `include_vir_assets` result to the
ResourceSet publication APIs. Migrate callers when updating the prototype. See
[resource integration](internals.md#resource-ownership-and-site-integration).

## Present a sequence of states

For a model in an ordinary Lean source module, import `VersoLeanRun.Views`.
It provides `Frame`, `Sequence`, `Automaton` and their view helpers. The document
imports its own genre adapter to select the function with `leanRun`; producer
modules need no document directives or publication setup.

Return `VersoLeanRun.SequenceView` to get previous/next, step selection and a
scrubber. The same entry works in Manual, Blog Page/Post and Slides. Define your
model with `Sequence α`, label each `SequenceStep α`, then supply a view using
Verso's existing `Html` type:

```lean
public def Demo.greetingSteps (name : String) : VersoLeanRun.SequenceView :=
  let sequence : VersoLeanRun.Sequence String := {
    initial := { label := "Start", state := name }
    steps := #[{ label := "Greeting", state := "Hello, " ++ name }] }
  sequence.view (Verso.Output.Html.text true)
```

Select it with `leanRun (entry := Demo.greetingSteps)`. No JSON, export marker or
output argument is needed. `SequenceStep.error` can report a failure at a state;
the initial state uses the same `SequenceStep` record as later states. Models and
views are ordinary Lean code and can live in imported modules with checked source anchors.
The [stack example](../demo/chapters/LeanRunSequence/Examples.lean) renders both sides
of each step from the calculator's [shared evaluator](../demo/chapters/LeanRunGate/Stack.lean).
Both views use one parser, execution loop, and set of limits. The stepper can inspect
a completed program with several stack values; the calculator additionally asks for
exactly one final result.

For an automaton `step : α → α`, use `Sequence.iterate step initial count`.
It records the initial state followed by exactly `count` transitions. Zero
transitions still give one state. The optional fourth argument labels iteration
indices, starting at zero:

```lean
def counter (seed : Nat) : SequenceView :=
  (Sequence.iterate (· + 1) seed 5 (fun i => s!"Iteration {i}")).view
    (fun n => Verso.Output.Html.text true (toString n))
```

Both `Sequence` and `SequenceView` require an initial state/frame and have an
optional array of later steps. A view cannot be empty. Report a failure before a
model state exists with `SequenceView.error`, rather than constructing a dummy
state:

```lean
SequenceView.error "The input could not be parsed."
```

Result-type abbreviations for `Html` and `SequenceView` work like the underlying
types. The presentation limits still apply to the resulting view; iteration does
not truncate a trace to fit them.

The worker computes states and renders their Html. Sequence frames cross the worker
boundary as typed VIR data, without a JSON envelope. Labels, markup and errors have
a combined 65,536 UTF-16 code unit budget. A separate Lean/VIR DOM
presenter owns Html documents, selection and event callbacks. Selecting a frame uses the computed
presentation and does not rerun the evaluator. Each placement owns both runtimes;
input edits, Stop and genre navigation cancel acquisition and dispose the view.
State Html uses the same script-disabled sandbox as an ordinary Html result.
Labels and failures are text, and exact natural numbers are rendered by Lean.

Presentations contain 1–128 frames and share the existing 65,536 UTF-16 output
limit. Large rendered sequences may exceed that limit even when their computation
is otherwise valid. Computation remains interruptible by terminating its worker.
The DOM presenter is a bounded experimental library, not a claim of general VIR
DOM qualification. Only its exercised bindings are covered here. Illuminate's
full animation compiler remains unqualified on the current runtime; its existing
qualified drawing-command/SVG output can be used inside a state Html view.

## Map and replay observations

The same pure machine can produce a finite trace or a live view:

```lean
let machine : Automaton Nat := { initial := 10, step := (· + 1) }
-- Finite: the initial state plus five transitions.
let finite : SequenceView := (machine.trace 5).viewText
-- Live: one transition per Step, with no retained history.
let live : AutomatonView := machine.viewText
```

`trace 0` observes the initial state without calling the transition. Trace
construction uses Lean's standard `List.scanl`. `Sequence.map` and the lawful
`Functor` instance (`f <$> trace`) transform states while preserving labels and
errors. `viewText` uses `ToString` and escapes the resulting text. Rich views can
still supply an explicit `α → Html` renderer.

To repeat a finite recording, use `trace.cycleView render`. It returns an
`AutomatonView`, replaying the initial observation and all later observations
before wrapping to the start. Duplicate states retain their distinct positions
and labels. Errors remain errors and pause playback. This is an explicit replay
policy; a recorded trace does not determine the transition that produced it.
The [exact-word example](../demo/chapters/LeanRunRendered/Examples.lean) shows a
finite trace and a cyclic replay of the same states.

For domain-specific live labels or failures, use `machine.observe`: its callback
receives the iteration index and state and returns a `Frame` containing `label`,
`html`, and optional `error`. Rendering remains pure; the library owns the worker
session. All views share `Frame.toWire` at the sandbox boundary.

## Run an automaton continuously

Return `AutomatonView` when a model should advance on demand instead of computing
an entire trace. `Automaton α` holds an initial model and a pure transition
`α → α`. `viewText` uses `ToString`; `view` accepts an `α → Html` renderer.
Both accept an optional iteration label:

```lean
public def counter (seed : Nat) : VersoLeanRun.AutomatonView :=
  let machine : VersoLeanRun.Automaton Nat := {
    initial := seed, step := (· + 1) }
  machine.viewText (fun i => s!"Iteration {i}")
```

Use the same `leanRun (entry := counter)` directive. The reader explicitly
starts the model and its playback:

| Action | Model and playback |
| --- | --- |
| Page load or first slide entry | Ready; no model or playback starts. |
| Run | Create the initial model, paused. |
| Play / Step | Advance continuously / advance once while paused. |
| Pause or hide the tab | Keep the model; an already requested transition may finish. |
| Return to the tab | Stay paused. |
| Edit input | Keep running the current model; edits are a draft. |
| Restart | Apply the draft to a fresh model; resume only if previously playing. |
| Stop, leave the placement, or cached-page exit | Terminate the worker and clear the view. |

Hiding during Restart cancels its pending resume intent even if the tab becomes
visible again before loading finishes. Stop and leaving the placement cancel it
too. Error frames disable Play/Step; Stop remains available to release their worker.

Each placement owns its model and worker. The worker keeps only the current
state, without collecting a frame history or imposing a generation count. The
player waits for a transition to finish before scheduling another, rather than
queuing ticks. Each rendered frame retains the 65,536 UTF-16 code unit budget
and the same sandbox policy as sequence views. A transition that does not return
remains interruptible with Stop. Report invalid input with
`AutomatonView.error`; its view disables Play and Step.

The [Game of Life example](../demo/chapters/LeanRunSequence/Life.lean) uses this
interface. Its input is a rectangular `#`/`.` seed of at most 8 rows and columns,
centred on an 8×8 board with dead cells beyond the edge. Lean computes and renders
every generation. A still life or an empty board continues to advance its
counter; Play has no trace boundary at which to stop. Use `SequenceView` instead
when readers need to inspect earlier states of a bounded computation.
