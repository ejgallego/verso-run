# Authoring runnable examples

A Run block selects a function with `entry`. Its Lean type chooses the input
control and result display. The document build handles VIR registration.

## A basic block

The same `leanRun` block works in Manual, Blog Page/Post and Slides. Select the
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

## Run an anchored example from an imported module

`leanRunAnchor` displays a standard Verso source anchor and selects a function
from an imported module. The producer is ordinary Lean, without VIR annotations:

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

The document creates a callable wrapper around the imported function. Its bundle
owns that wrapper and includes the producer's compiled dependencies. Register and
publish the **document module's** resource bundle, just as for inline examples;
the producer needs no separate export marker or root bundle. Imported `String →
Html` functions use the same automatic serialization and preview as inline ones.
Only same-project execution is qualified.

Input, `+multiline` and `+collapsed` work across Manual, Blog and Slides. Standard
source options such as `-showProofStates` and `-defSite` remain available. Open
`Verso.Code.External` for the ordinary `anchor` block. Use `-defSite` on repeated
Manual displays when another block already owns the desired definition target.
An ordinary `anchor` can show the same source without a Run form.

`leanRun` defines or reuses a function directly in any of the three genres.
Namespace, open declarations and definitions remain available in later Run blocks.
`leanRunAnchor` is optional when several documents share an imported source region.
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
public def lifeView (seed : String) : SequenceView :=
  match parse seed with
  | .error message => SequenceView.error message
  | .ok board => (simulate board).view renderState
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

The [Game of Life example](../demo/chapters/LeanRunSequence/Life.lean) is another
ordinary `String → SequenceView` function. Its input is a rectangular `#`/`.` seed
of at most 8 rows and columns, centred on an 8×8 board. The model computes twelve
generations with dead cells beyond the edge, then its view renders an SVG board.
It uses the same player and worker lifecycle as the stack stepper. No JavaScript
implements the simulation or interprets its trace.
