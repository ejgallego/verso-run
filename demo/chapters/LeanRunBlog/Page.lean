module
public import VersoLeanRun.Blog
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import LeanRunGate.Helper
import LeanRunTyped.Examples

open Verso Genre Blog VersoLeanRun.Blog

open Verso.Code.External

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (Page) "A runnable Verso page" =>

A page can include the same checked source as a manual or a blog post.
Choose a natural number and run the imported function below. Inputs larger than
JavaScript's safe integer range remain exact.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

[Read the runnable post](notes/2026-10-8-running-lean-in-a-post/).

# Typed inputs

Choose a Boolean or increment an exact unsigned 64-bit integer.

```leanRunAnchor flip (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.flip)
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
```

```leanRunAnchor increment (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.increment) (input := "9007199254740993")
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
```

# Multiline text

Keep line breaks while editing. Ctrl+Enter or ⌘+Enter runs the example.

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
```

# Define a runnable function here

Inline Run blocks compile their definitions in this document. No source anchor
or export annotation is needed. Later blocks can reuse the definition.

```leanRun (entry := LeanRunBlog.Page.Inline.greet) (input := "Ada")
namespace LeanRunBlog.Page.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRun (entry := greet) (input := "Grace")
#check greet
```

# Return typed HTML

```leanRun (entry := LeanRunBlog.Page.Inline.card) (input := "Ada")
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunBlog.Page.Inline
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +")
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
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

# Game of Life

Edit a rectangular seed: `#` is a live cell and `.` is a dead cell. The seed is
centred on an 8×8 board; cells outside the edge stay dead. Lean computes each
generation on demand. Choose Play to keep running, Pause to inspect the board,
or Step to advance once. Edit a new seed while it runs, then choose Restart
to apply it. Stop releases the worker.
Try `###` on one line for a blinker, or `##` on each of two lines for a still life.

```leanRunAnchor lifeView (module := LeanRunSequence.Life) (entry := LeanRunSequence.Life.lifeView) (input := "...\n###\n...") +multiline
public def lifeView (seed : String) : VersoLeanRun.AutomatonView :=
  match parse seed with
  | .error message => AutomatonView.error message
  | .ok board =>
    let machine : Automaton State := {
      initial := { board }, step := State.step }
    machine.view renderState (fun n => s!"Generation {n}")
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

## The model

The model adds a generation counter to the board. The player calls this transition
without interpreting the board in JavaScript.

```anchor lifeState (module := LeanRunSequence.Life)
structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }
```

## The view

Lean renders the board as ordinary SVG inside Verso Html.

```anchor lifeSvg (module := LeanRunSequence.Life)
def renderState (state : State) : Html :=
  {{ <div style="padding:.5rem">
    <p style="margin:0 0 .5rem;font-weight:600">{{s!"Generation {state.generation} · {state.board.population} living cells"}}</p>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img"
         aria-label={{s!"Game of Life generation {state.generation}, {state.board.population} living cells"}}
         style="display:block;width:176px;height:176px;max-width:100%;background:#f3f6fa">
      <path class="life-cells" d={{livePath state.board}} fill="#285674"> " " </path>
      <path d={{gridPath}} fill="none" stroke="#ccd9e5" stroke-width=".5"> " " </path>
    </svg>
  </div> }}
```
