# Authoring runnable examples

A Run block displays Lean code alongside controls for calling a function.
The `entry` argument names the function, and its Lean type determines the input
control and result display. The document build prepares it for browser execution.

## A basic block

`leanRun` works in Manual, Blog pages and posts, and Slides. Each genre has its
own adapter import. A minimal Manual chapter looks like this:

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

The function must be public, executable, and monomorphic. Scalar and HTML
entries, as well as sequence and automaton model functions, must be pure;
custom live views return an `AutomatonView` action. No `@[vir_export]` attribute
is required: the build handles VIR registration and checks the entry and any
helper functions it calls. Existing explicit export attributes remain supported.

Definitions, namespaces, and open declarations remain available in later Run
blocks. Several blocks can use the same entry; a later block might display just
`#check Demo.greet` while providing another set of controls. Each embedded
example runs independently.
Ordinary `lean` blocks keep their existing behavior. `-keep`, `+error` and unknown
Run arguments are rejected.

## Arguments and defaults

| Argument | Meaning | Default |
| --- | --- | --- |
| `(entry := My.function)` | Select the function | Required |
| `(input := "...")` | Initial reader input; does not run on page load | Empty String, `"0"` for Nat/UInt64, `"false"` for Bool |
| `+multiline` | A textarea for a String argument | Off |
| `+collapsed` | Initially folded source | Off |

`Bool` inputs use a true/false selector, with presets written as the strings
`"true"` or `"false"`. `Nat` and `UInt64` inputs use exact decimal values; UInt64 is bounded
by `18446744073709551615` and arithmetic uses Lean's normal wraparound. Values
beyond JavaScript's safe integer range remain exact.

`+multiline` displays a String input in a textarea, preserving whitespace and
blank lines. Enter adds a newline; Ctrl+Enter or ⌘+Enter runs the function.
The option is only available for String inputs. String input is limited to
4096 UTF-16 code units; result limits are described below.

`+collapsed` puts source in an expandable “View Lean implementation” panel.
Source remains present in HTML and Manual TeX, including without JavaScript.

## The result type chooses the display

| Function type | Result display |
| --- | --- |
| `String → String`, `Nat → Nat`, `Bool → Bool`, `UInt64 → UInt64` | Plain text |
| `String`, `Nat`, `Bool`, or `UInt64` → `Verso.Output.Html` | An isolated HTML preview |
| `String`, `Nat`, `Bool`, or `UInt64` → `VersoLeanRun.Sequence α` or `SequenceView` | Labelled states with selection and scrubbing |
| `String`, `Nat`, `Bool`, or `UInt64` → `VersoLeanRun.Automaton α` or `AutomatonView` | A live simulation with Step, Play, Pause, and Stop |

For a plain `Sequence α` or `Automaton α`, HTML states keep their markup;
other states need a `ToString` instance and appear as escaped text. The model type
must be fixed, rather than depend on the input value. Use `.view render` for a
custom HTML or SVG display, including model types without `ToString`.

Text results are limited to 65,536 UTF-16 code units. In HTML and frame results,
the strings share that limit, including labels, content, and errors.
Structured results also have node and depth limits; see
[execution limits](internals.md#interaction-and-limits).

A String containing markup is still plain text. There is no `output` block
argument. Return `Html` when the result is intended to be rendered as HTML:

````lean
```leanRun (entry := Demo.card) (input := "Ada")
open Verso.Output.Html
public def Demo.card (name : String) : Verso.Output.Html :=
  html%{<h2>Hello, {name}!</h2>}
```
````

Verso's typed HTML syntax escapes interpolated text and attributes. Raw HTML
nodes remain an explicit author choice. The preview supports static HTML, inline
CSS and data images; scripts and external embedded resources are disabled.
The preview clears when the input changes, a new call starts, Stop is pressed,
or a call fails. Errors appear as plain text. Larger results can be scrolled
within the preview.

## Run an anchored example from an imported module

`leanRunAnchor` displays a standard Verso source anchor and selects a function
from an imported module. The source module is ordinary Lean, without VIR annotations:

```lean
module
-- ANCHOR: twice
public def Examples.twice (n : Nat) : Nat := n + n
-- ANCHOR_END: twice
```

Import the source module into the document. Verso's project and module defaults
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
The body must match the source region. Verso suggests a replacement when the
body is stale and can fill in an empty body. Anchor comments are not displayed.

Publish the **document module's** resource bundle, just as for inline examples.
It includes the selected function and its compiled dependencies; the source module
needs no separate export marker or bundle registration. Imported HTML functions
use the same preview as inline definitions. Execution from anchors is currently
tested only within the same project.

Input, `+multiline` and `+collapsed` work across Manual, Blog and Slides. Standard
source options such as `-showProofStates` and `-defSite` remain available. Open
`Verso.Code.External` for the ordinary `anchor` block. Use `-defSite` on repeated
Manual displays when another block already owns the desired definition target.
An ordinary `anchor` can show the same source without a Run form.

`leanRun` defines or reuses a function directly in any of the three genres.
Namespaces, open declarations, and definitions remain available in later Run blocks.
`leanRunAnchor` is optional when several documents share an imported source region.
Each genre retains native source styling and links. See
[Blog authoring](blog.md) and [Slides authoring](slides.md).

## Project wiring and migration

A document must not import the module that embeds its generated resources: that
would create a build dependency cycle. The native generator imports both the
document and its separate resource carrier.
See [resource integration](internals.md#resource-ownership-and-site-integration).
Retain `compiler.postponeCompile false`; native precompilation remains deferred.

When updating an older example, remove redundant `@[vir_export]` markers and
`output` options. Change functions that serialize HTML to a String to return
`Html` directly. For anchors, move root resource registration from the imported
producer to the document module. The independently pinned
[Manual starter](../examples/manual-starter/README.md) demonstrates entry-selected
text and HTML functions without explicit export annotations. It uses a pinned
published version, tested separately from this development checkout.
New generators should pass the complete `include_vir_assets` result to the
ResourceSet publication APIs. See
[resource integration](internals.md#resource-ownership-and-site-integration).

## Present a sequence of states

For a model in an ordinary Lean source module, import `VersoLeanRun.Views`.
It provides `Frame`, `Sequence`, `Automaton`, and their view helpers. The document
imports the adapter for its genre. Model modules need no document directives
or publication setup.
The generated [View API reference](https://ejgallego.github.io/verso-run/api/)
explains these types and helpers with Lean-checked examples and linked source.

A function returning `VersoLeanRun.Sequence α` or `SequenceView` gets controls
for browsing its frames, including step selection and a scrubber. It works in all three genres.
`Sequence α` records model values, while `SequenceView` contains HTML ready to
display. For text values, the default renderer is enough:

```lean
public def Demo.greetingSteps (name : String) : VersoLeanRun.Sequence String :=
  { initial := { label := "Start", content := name }
    steps := #[{ label := "Greeting", content := "Hello, " ++ name }] }
```

The block `leanRun (entry := Demo.greetingSteps)` displays this sequence.
`Frame.error` can report a failure at a particular step;
the initial state uses the same `Frame` record as later states. Models and
views are ordinary Lean code and can live in imported modules with checked source anchors.
The [stack example](../demo/chapters/LeanRunSequence/Examples.lean) renders both sides
of each step from the calculator's [shared evaluator](../demo/chapters/LeanRunGate/Stack.lean).
Both examples use the same parser, execution loop, and limits. The stepper accepts
a completed program with several values left on its stack; the calculator requires
exactly one final value.

`Sequence.iterate step initial count` records the initial state followed by
exactly `count` applications of a transition `step : α → α`. Zero transitions
still give one state. The optional fourth argument labels the steps, starting
at zero:

```lean
def counter (seed : Nat) : Sequence Nat :=
  Sequence.iterate (· + 1) seed 5 (fun i => s!"Iteration {i}")
```

Every `Sequence` contains an initial frame and an optional array of later steps.
`SequenceView` is `Sequence Html`, so a displayed sequence cannot be empty.
`SequenceView.error` reports a failure when there is no model state to display:

```lean
SequenceView.error "The input could not be parsed."
```

Type aliases for `Html` and `SequenceView` work like the underlying types.
Oversized sequences are rejected; `iterate` does not shorten them to fit the
display limits.

Selecting a frame displays a recorded result; it does not rerun the computation.
Each example is independent. Input edits, Stop, and leaving the example clear its
view. Frame content uses the same script-disabled preview as an ordinary HTML
result; labels and errors are displayed as text.

A displayed sequence contains 1–128 frames. Its strings, including labels,
content, and errors, share a limit of 65,536 UTF-16 code units. A large drawing
can exceed this limit even in a short sequence. Oversized results are rejected,
rather than silently shortened. Stop interrupts a computation that has not
finished.

Illuminate's drawing-command/SVG output can provide a frame's content. Its full
animation compiler is not qualified on the current runtime; see the
[Illuminate support limits](../evidence/illuminate-gates.md).

## Map and replay observations

The same automaton can produce a finite trace or a live view:

```lean
let machine : Automaton Nat := { initial := 10, step := (· + 1) }
-- Finite: the initial state plus five transitions.
let finite : SequenceView := (machine.trace 5).view
-- Live: one transition per Step, with no retained history.
let live : AutomatonView := machine.view
```

`trace 0` observes the initial state without calling the transition.
`Sequence.map` and the standard `Functor` notation (`f <$> trace`) transform
states while preserving labels and errors. `view` keeps HTML values and displays
other values as escaped text using `ToString`. A custom `α → Html` renderer can
produce a richer display.

To repeat a finite recording, use `trace.cycleView`, with an optional drawing
function just as for `view`. It returns an `AutomatonView` that displays each
recorded frame in order, then returns to the start. Duplicate states keep their positions
and labels. An error displays the failure and disables Play and Step until a
fresh run. Replay uses the saved frames and does not recompute the states.
The [exact-word example](../demo/chapters/LeanRunRendered/Examples.lean) shows a
finite trace and a cyclic replay of the same states.

`machine.observe` supports labels and errors based on the current state. Its
callback receives the step number and state and returns a `Frame` containing
`label`, `content`, and an optional `error` message.

## Run an automaton continuously

`AutomatonView` computes a new state on demand, without recording an entire
trace. `Automaton α` holds an initial state and a pure transition `α → α`.
Its `view` helper accepts an optional `α → Html` renderer and a function that
labels the steps. The default renderer preserves HTML and displays other values
as escaped text using `ToString`:

```lean
public def counter (seed : Nat) : VersoLeanRun.Automaton Nat :=
  { initial := seed, step := (· + 1) }
```

The block `leanRun (entry := counter)` provides playback controls without a call
to `.view`. For custom labels, return `(counter seed).view (label := ...)` from a
separate entry. Ordinary Lean code still uses `.view` explicitly to start a
session; `leanRun` generates that adapter when compiling the document.
Opening the page leaves the example idle:

| Action | Model and playback |
| --- | --- |
| Page load or first slide entry | Ready; no model or playback starts. |
| Run | Create the initial model, paused. |
| Play / Step | Advance continuously / advance once while paused. |
| Pause or hide the tab | Keep the model; an already requested transition may finish. |
| Return to the tab | Stay paused. |
| Edit input | Keep running the current model; edits are a draft. |
| Restart | Apply the draft to a fresh model; resume only if previously playing. |
| Stop or leave the example, including navigating away | End the run and clear the view. |

Hiding the tab while Restart is loading leaves playback paused, even if the tab
becomes visible again before loading finishes. Stop and leaving the example also
cancel automatic resumption. Error frames disable Play and Step; Stop still
ends the run and clears the view.

Each embedded example has independent state. It keeps only the current state,
with no fixed step limit. Play waits for each transition to finish before
starting the next. Each frame has the same 65,536 UTF-16 code unit string limit
and HTML preview restrictions as sequence views. Stop can interrupt a transition
that has not finished. `AutomatonView.error` reports invalid input with Play and
Step disabled.

The [Game of Life example](../demo/chapters/LeanRunSequence/Life.lean) uses this
interface. Its input is a rectangular `#`/`.` seed of at most 8 rows and columns,
centred on an 8×8 board with dead cells beyond the edge. Lean computes and renders
every generation. A still life or an empty board continues to advance its
counter; Play has no trace boundary at which to stop. Use `SequenceView` instead
when readers need to inspect earlier states of a bounded computation.
