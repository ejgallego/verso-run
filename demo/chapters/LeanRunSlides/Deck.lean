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

Edit the input and choose Run. Try `9007199254740993`: Lean keeps the exact value.
Use the arrows to change slides.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

# A greeting, on reveal

Advance once to reveal the example. Hiding it again stops the run.

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

Run blocks can define functions directly in the deck. Their source uses the
same highlighting and fragments as ordinary Slides code blocks.

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
open Verso.Output.Html

public def card (name : String) : Verso.Output.Html :=
  {{ <p> {{name}} </p> }}
end LeanRunSlides.Deck.Inline
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

# Exact word states

This recorded sequence has two frames: the input and its successor.
Run, then move from Start to Increment to see the maximum `UInt64` wrap to zero.

```leanRunAnchor wordSteps (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.wordSteps) (input := "18446744073709551615")
public def wordSteps (seed : UInt64) : SequenceView :=
  let machine : Automaton UInt64 := { initial := seed, step := (· + 1) }
  (machine.trace 1 (fun i => if i == 0 then "Start" else "Increment")).view
    fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
```

# Game of Life

Run, then Play or Step. Restart applies an edited seed.

```leanRunAnchor lifeView (module := LeanRunSequence.Life) (entry := LeanRunSequence.Life.lifeView) (input := "...\n###\n...") +multiline
public def lifeView (seed : String) : VersoLeanRun.AutomatonView :=
  match parse seed with
  | .error message => AutomatonView.error message
  | .ok board =>
    let machine : Automaton State := {
      initial := { board }, step := State.step }
    machine.view renderState (fun n => s!"Generation {n}")
```

# The transition

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

# The model

The state pairs the board with a generation counter. Each step advances the
board using the rule above and increments the counter.

```anchor lifeState (module := LeanRunSequence.Life)
structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }
```

# The view

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
