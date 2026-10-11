module
public import VersoLeanRun.Blog
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import LeanRunBlog.Examples

open Verso Genre Blog VersoLeanRun.Blog

open Verso.Code.External

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (Post) "Running Lean in a post" =>

%%%
authors := ["verso-run"]
date := {year := 2026, month := 10, day := 8}
%%%

A Lean function can return an answer, a trace to inspect, or a model that keeps
evolving. The examples below move through those three kinds of interaction,
using checked source from ordinary Lean modules. Edit inputs and compare the
results with the definitions that compute them.

# A greeting

```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Grace")
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor card (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.card) (input := "Ada")
public def LeanRunBlog.Examples.card (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}
```

Text interpolated into typed HTML is escaped before serialization.

```leanRunAnchor counting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10")
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

Try `1000000000000`, then press Stop while the worker counts.

# Stack stepper

Run `6 7 * 2 +`, then use the instruction strip, Previous/Next, or the slider
to inspect each state. The stack's top is on the right.

* Try `5 dup *`: which instruction copies the top value?
* Try `2 +`: inspect the unchanged stack at the failing instruction.
* Try `9007199254740993 2 *`: the values stay exact beyond JavaScript's safe integer range.

Lean computes the trace once. Selecting a step displays its stored state without
rerunning the program. The calculator and this view use the same evaluator;
only the calculator requires one final value.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +")
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```

## From execution to a sequence

The evaluator records each instruction’s before/after stacks and any error.
This adapter makes those snapshots a sequence, including the initial empty stack.

```anchor stackSequence (module := LeanRunSequence.Examples)
/-- The view uses the ordinary evaluator's instruction snapshots directly. -/
abbrev Snapshot := LeanRunGate.Stack.TraceStep

def evaluate (program : String) : Sequence Snapshot :=
  let trace := LeanRunGate.Stack.evaluate program
  let start : Snapshot := { label := "Start", before := [], after := [] }
  { initial := { label := "Start", state := start, error := trace.initialError }
    steps := trace.steps.map fun step => { label := step.label, state := step, error := step.error } }
```

## Render a selected state

The view renders both stacks as Verso HTML. Selection controls are shared by
all sequence examples; this function defines only what a machine state looks like.

```anchor stackRendering (module := LeanRunSequence.Examples)
private def stackCells (values : List Nat) : Html :=
  if values.isEmpty then {{ <p> "Empty stack" </p> }}
  else Html.fromArray <| (values.reverse.map fun n =>
    {{ <span style="display:inline-block;padding:.5rem .75rem;margin:.2rem;border:1px solid #cbd8e6;border-radius:5px;background:#edf5ff">{{toString n}}</span> }}).toArray

def renderSnapshot (snapshot : Snapshot) : Html :=
  {{ <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1rem;padding:.5rem">
    <section><h3> "Before" </h3>{{stackCells snapshot.before}}</section>
    <section><h3> "After" </h3>{{stackCells snapshot.after}}</section>
  </div> }}
```

[Read the parser and execution rules](https://github.com/ejgallego/verso-run/blob/main/demo/chapters/LeanRunGate/Stack.lean).


# Game of Life

Choose Run to load the seed, then Play to let it evolve or Step to inspect a
single generation. Pause keeps the board; Stop releases the worker. Edits to
the seed take effect on Restart, so you can prepare a new pattern while it runs.

Use `#` for a live cell and `.` for a dead cell. Try these small experiments:

* *Blinker:* `###` on one line. After two steps, does it return to its first state?
* *Still life:* `##` on each of two lines. Why does every live cell survive?
* *Glider:* `.#.`, `..#`, `###` on three lines. Watch it move towards the edge.

The seed is centred on an 8×8 board. Cells beyond the edge stay dead, so the
glider eventually reaches a boundary; the simulation continues without wrapping.

```leanRunAnchor lifeView (module := LeanRunSequence.Life) (entry := LeanRunSequence.Life.lifeView) (input := "...\n###\n...") +multiline
public def lifeView (seed : String) : VersoLeanRun.AutomatonView :=
  match parse seed with
  | .error message => AutomatonView.error message
  | .ok board =>
    let machine : Automaton State := {
      initial := { board }, step := State.step }
    machine.view renderState (fun n => s!"Generation {n}")
```

## The model

The model adds a generation counter to the board. The player calls this transition
without interpreting the board in JavaScript.

```anchor lifeBoard (module := LeanRunSequence.Life)
def side : Nat := 8

/-- The finite board has dead cells outside its boundary; it does not wrap. -/
structure Board where
  cells : Array Bool := Array.replicate (side * side) false
  deriving BEq, Repr

def Board.alive (board : Board) (row col : Nat) : Bool :=
  row < side && col < side && board.cells[row * side + col]?.getD false

def Board.population (board : Board) : Nat :=
  board.cells.foldl (fun n live => if live then n + 1 else n) 0
```

```anchor lifeState (module := LeanRunSequence.Life)
structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }
```

## The transition

Every new cell reads the old board: birth with three neighbours, survival with
two or three. This pure function contains the complete Life rule.

```anchor lifeRules (module := LeanRunSequence.Life)
def Board.neighbours (board : Board) (row col : Nat) : Nat := Id.run do
  let mut count := 0
  for dr in [:3] do
    for dc in [:3] do
      if dr == 1 && dc == 1 then continue
      if (dr == 0 && row == 0) || (dc == 0 && col == 0) then continue
      if board.alive (row + dr - 1) (col + dc - 1) then count := count + 1
  return count

/-- B3/S23: birth with three neighbours, survival with two or three.
Every new cell reads the old board, so updates are simultaneous. -/
def Board.step (board : Board) : Board :=
  { cells := (Array.range (side * side)).map fun i =>
      let row := i / side
      let col := i % side
      let n := board.neighbours row col
      n == 3 || (board.alive row col && n == 2) }
```

## The view

Lean renders the board as ordinary SVG inside Verso Html.

```anchor lifeSvg (module := LeanRunSequence.Life)
def renderState (state : State) : Html :=
  {{ <div style="padding:.5rem">
    <p style="margin:0 0 .5rem;font-weight:600">{{s!"{state.board.population} living cells"}}</p>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img"
         aria-label={{s!"Game of Life generation {state.generation}, {state.board.population} living cells"}}
         style="display:block;width:288px;height:auto;max-width:100%;margin:0 auto;background:#f3f6fa">
      <path class="life-cells" d={{livePath state.board}} fill="#285674"> " " </path>
      <path d={{gridPath}} fill="none" stroke="#ccd9e5" stroke-width=".5"> " " </path>
    </svg>
  </div> }}
```

[Read the complete Life module](https://github.com/ejgallego/verso-run/blob/main/demo/chapters/LeanRunSequence/Life.lean), including seed parsing and SVG path construction.

# Define a runnable function here

Inline Run blocks compile their definitions in this document. No source anchor
or export annotation is needed. Later blocks can reuse the definition.

```leanRun (entry := LeanRunBlog.Post.Inline.greet) (input := "Ada")
namespace LeanRunBlog.Post.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRun (entry := greet) (input := "Grace")
#check greet
```

# Return typed HTML

```leanRun (entry := LeanRunBlog.Post.Inline.card) (input := "Ada")
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunBlog.Post.Inline
```

# Typed rendering

The input type selects its control; the result type selects its view.

```leanRunAnchor badge (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.badge) (input := "true")
public def badge (enabled : Bool) : Html :=
  {{ <p><strong>{{if enabled then "Enabled" else "Disabled"}}</strong></p> }}
```

```leanRunAnchor wordSteps (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.wordSteps) (input := "18446744073709551615")
public def wordSteps (seed : UInt64) : SequenceView :=
  let sequence : Sequence UInt64 := {
    initial := { label := "Start", state := seed }
    steps := #[{ label := "Increment", state := seed + 1 }] }
  sequence.view fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
```
