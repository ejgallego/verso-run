module
public import VersoLeanRun.Slides
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import LeanRunGate.Helper
import LeanRunBlog.Examples
import LeanRunTyped.Examples

open Verso Doc VersoSlides VersoLeanRun.Slides

open Verso.Code.External

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (VersoSlides.Slides) "Lean you can run" =>

# Exact natural numbers

Three ways to explore Lean: an exact calculation, a trace you can inspect, and
a simulation you can keep running. Start with `9007199254740993`, then Run.
Lean doubles it exactly. Use the arrows to move on.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +")
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```

# Game of Life

Run the seed, then Play. The blinker repeats every two generations.
Try `##` on each of two lines for a still life. Edit while playing, then Restart
to apply the new seed. The 8×8 board has dead cells beyond its edges.

```leanRunAnchor lifeView (module := LeanRunSequence.Life) (entry := LeanRunSequence.Life.lifeView) (input := "...\n###\n...") +multiline
public def lifeView (seed : String) : VersoLeanRun.AutomatonView :=
  match parse seed with
  | .error message => AutomatonView.error message
  | .ok board =>
    let machine : Automaton State := {
      initial := { board }, step := State.step }
    machine.view renderState (fun n => s!"Generation {n}")
```

# The board

The board is an array of live/dead cells. Reading beyond its edges returns false.

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

# The model

The model adds a generation counter. The worker calls this pure transition;
it does not interpret the board in JavaScript.

```anchor lifeState (module := LeanRunSequence.Life)
structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }
```

# The transition

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

# The view

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

# More examples

The following slides cover HTML, typed inputs, inline definitions, and worker
lifecycle. Use them as an appendix when presenting the three main demonstrations.

# A greeting, on reveal

Advance once to reveal the example. Its worker stops when the fragment is hidden.

:::fragment
```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
:::

# Stop when you leave

Run `1000000000000`, then choose Stop or move to another slide.

```leanRunAnchor counting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10")
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

# An HTML card

The same isolated HTML preview works in a slide.

```leanRunAnchor card (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.card) (input := "Ada")
public def LeanRunBlog.Examples.card (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}
```

# A Boolean choice

Choose true or false, then Run.

```leanRunAnchor flip (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.flip)
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
```

# Exact UInt64

Try `9007199254740993`, then the maximum `18446744073709551615`.
Incrementing the maximum wraps to zero.

```leanRunAnchor increment (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.increment)
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
```

# Multiline String

Enter adds a line break; Ctrl+Enter or ⌘+Enter runs the example.

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
```

# Define a runnable function here

The same inline Run syntax works in a deck. Its source uses native Slides rendering.

:::fragment
```leanRun (entry := LeanRunSlides.Deck.Inline.greet) (input := "Ada")
namespace LeanRunSlides.Deck.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
:::

# Reuse the inline definition

The namespace and definition remain available in later blocks.

```leanRun (entry := greet) (input := "Grace")
#check greet
```

# Inline typed HTML

```leanRun (entry := LeanRunSlides.Deck.Inline.card) (input := "Ada")
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunSlides.Deck.Inline
```

# Typed rendering

The input type selects its control; the result type selects its view.

```leanRunAnchor badge (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.badge) (input := "true")
public def badge (enabled : Bool) : Html :=
  {{ <p><strong>{{if enabled then "Enabled" else "Disabled"}}</strong></p> }}
```

# Exact word states

```leanRunAnchor wordSteps (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.wordSteps) (input := "18446744073709551615")
public def wordSteps (seed : UInt64) : SequenceView :=
  let sequence : Sequence UInt64 := {
    initial := { label := "Start", state := seed }
    steps := #[{ label := "Increment", state := seed + 1 }] }
  sequence.view fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
```
