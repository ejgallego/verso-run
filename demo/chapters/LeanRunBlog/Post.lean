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

A blog post can include runnable functions defined in another Lean module,
with their source displayed alongside the controls.
Edit an input, choose Run, and use Stop to interrupt the counting example.

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

HTML interpolation escapes the name, so reader input appears as text rather
than markup.

```leanRunAnchor counting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10")
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

Try `1000000000000`, then press Stop while it counts.

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

A function can return Verso's `Html` type. This small example displays the name
as escaped text in an isolated preview.

```leanRun (entry := LeanRunBlog.Post.Inline.card) (input := "Ada")
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunBlog.Post.Inline
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +")
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```

# Typed rendering

A Boolean input gets a true/false choice. Returning `Html` displays the result
in a preview.

```leanRunAnchor badge (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.badge) (input := "true")
public def badge (enabled : Bool) : Html :=
  {{ <p><strong>{{if enabled then "Enabled" else "Disabled"}}</strong></p> }}
```

A sequence adds navigation between recorded results. This one shows an exact
unsigned integer and its successor; incrementing the maximum wraps to zero.

```leanRunAnchor wordSteps (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.wordSteps) (input := "18446744073709551615")
public def wordSteps (seed : UInt64) : SequenceView :=
  let machine : Automaton UInt64 := { initial := seed, step := (· + 1) }
  (machine.trace 1 (fun i => if i == 0 then "Start" else "Increment")).view
    fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
```

# Game of Life

Edit a rectangular seed: `#` is a live cell and `.` is a dead cell. The seed is
centred on an 8×8 board; cells outside the edge stay dead. Lean computes each
generation on demand. Choose Play to keep running, Pause to inspect the board,
or Step to advance once. Edit a new seed while it runs, then choose Restart
to apply it. Stop ends the run.

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

A dead cell becomes alive with exactly three live neighbours; a live cell survives with
two or three. Each update reads the old board, so all cells change simultaneously.

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

The state pairs the board with a generation counter. Each step advances the
board using the rule above and increments the counter.

```anchor lifeState (module := LeanRunSequence.Life)
structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }
```

## The view

The display function returns SVG inside Verso's `Html` type, with a label showing
the generation and number of live cells.

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
