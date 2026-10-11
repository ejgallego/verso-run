module
public import VersoLeanRun
import LeanRunGate.Helper
import LeanRunTyped.Examples
import LeanRunGate.Stack
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
public import Illuminate.Render.Svg
public import Illuminate.Geometry.PathData
public import Illuminate.Geometry.Matrix
public import Illuminate.Style.Color

open Verso Genre Manual InlineLean VersoLeanRun
open Verso.Code.External

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (Manual) "Run compiled Lean" =>

Try the Lean functions shown below. Change an input, then choose Run to see the result.
Use Stop to interrupt a calculation.

# Greeting

```leanRun (entry := LeanRunGate.greet) (input := "Ada")
public def LeanRunGate.greet (name : String) : String :=
  "Hello, " ++ name
```

# Stack calculator

Write a little program with numbers and operations separated by spaces.
Run the supplied `6 7 * 2 +` program to compute `(6 × 7) + 2` and see each step.
Open the implementation to explore its Lean instruction type, parser, and execution rules.

```leanRunAnchor stack (module := LeanRunGate.Stack) (entry := LeanRunGate.Stack.run) (input := "6 7 * 2 +") +collapsed
namespace LeanRunGate.Stack

public inductive Instruction where
  | push (n : Nat) | add | mul | dup | swap

public def parse (word : String) : Except String Instruction :=
  match word with
  | "+" => .ok .add
  | "*" => .ok .mul
  | "dup" => .ok .dup
  | "swap" => .ok .swap
  | _ => match word.toNat? with
    | some n => .ok (.push n)
    | none => .error "unknown instruction or natural number"

public def step : Instruction → List Nat → Except String (List Nat)
  | .push n, stack => .ok (n :: stack)
  | .add, a :: b :: stack => .ok ((b + a) :: stack)
  | .mul, a :: b :: stack => .ok ((b * a) :: stack)
  | .dup, a :: stack => .ok (a :: a :: stack)
  | .swap, a :: b :: stack => .ok (b :: a :: stack)
  | _, _ => .error "not enough values on the stack"

public def showStack (stack : List Nat) : String :=
  "[" ++ ", ".intercalate (stack.reverse.map toString) ++ "]"

/-- One instruction attempt, including the unchanged stack when it fails. -/
public structure TraceStep where
  label : String
  before : List Nat
  after : List Nat
  error : Option String := none

/-- The shared evaluator's result, independent of text or HTML presentation. -/
public structure Trace where
  steps : Array TraceStep := #[]
  initialError : Option String := none

public def evaluate (program : String) : Trace := Id.run do
  let words := (program.splitOn " ").filter (!·.isEmpty)
  if words.isEmpty then return { initialError := some "Enter a program, for example: 6 7 * 2 +" }
  if words.length > 32 then return { initialError := some "Use at most 32 instructions." }
  let mut stack : List Nat := []
  let mut trace : Trace := {}
  for word in words do
    let next := parse word >>= fun instruction => step instruction stack
    match next with
    | .error message =>
        return { trace with steps := trace.steps.push {
          label := word, before := stack, after := stack,
          error := some s!"Error at '{word}': {message}" } }
    | .ok values =>
        if values.length > 16 || values.any (fun n => (toString n).length > 80) then
          return { trace with steps := trace.steps.push {
            label := word, before := stack, after := stack,
            error := some "Stack or number limit reached." } }
        trace := { trace with steps := trace.steps.push {
          label := word, before := stack, after := values } }
        stack := values
  return trace

/-- A calculator adds its single-result rule to the shared operational trace. -/
public def run (program : String) : String := Id.run do
  let trace := evaluate program
  if let some error := trace.initialError then return error
  let lines := #["Start: []"] ++ trace.steps.map fun step =>
    step.error.getD s!"{step.label}  →  {showStack step.after}"
  let text := "\n".intercalate lines.toList
  let final := trace.steps.back?
  if (final.bind (·.error)).isSome then return text
  let stack := (final.map (·.after)).getD []
  let result := match stack with
    | [n] => s!"Result: {n}"
    | _ => "Finish with exactly one value on the stack."
  return text ++ "\n\n" ++ result

end LeanRunGate.Stack
```

Try another program:

* `5 dup *` squares five, giving 25.
* `2 3 swap dup * +` swaps the top two values before duplicating and squaring, giving 7.
* `9007199254740993 2 *` gives an exact answer beyond JavaScript's safe integer range.
* `2 +` or an unknown word shows how the interpreter reports mistakes.

The stack's top is on the right. `+` and `*` combine two values, `dup` copies one,
and `swap` exchanges two. A complete program leaves exactly one result.
The demo accepts at most 32 instructions, 16 stack values, and 80 decimal digits per value.

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

*From execution to a sequence*

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

*Render a selected state*

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


# HTML greeting

Lean can also return HTML. Change the name and run this example to build a small greeting card.
The function returns Verso's `Html` type. The form serializes it for the HTML preview,
and interpolated text is escaped automatically.

```leanRun (entry := LeanRunGate.htmlGreeting) (input := "Ada")
open Verso.Output.Html

public def LeanRunGate.htmlGreeting (name : String) : Verso.Output.Html :=
  let name := if name.isEmpty then "friend" else name
  {{ <section style="padding:1.25rem;background:#edf5ff;border-radius:8px">
    <p style="margin:0 0 .5rem;color:#536273;font-size:.8rem"> "A greeting from Lean" </p>
    <h2 style="margin:0;color:#285575"> "Hello, " {{name}} "!" </h2>
    <p style="margin:.75rem 0 0"> "Welcome to the demo." </p>
  </section> }}
```

The same typed HTML function also accepts multiline text. Line breaks and reader
markup remain text inside the isolated preview.

```leanRun (entry := LeanRunGate.htmlGreeting) (input := "Ada\nGrace") +multiline
#check LeanRunGate.htmlGreeting
```

# Illuminate diagrams

Choose a number from 1 to 8, then Run to build a chain of numbered nodes.
Try `1`, `4`, and `8`: the labels, links, and layout are computed by Lean in your browser.

```leanRun (entry := LeanRunGate.diagram) (input := "4")
open Illuminate Verso.Output.Html

public def LeanRunGate.diagram (count : Nat) : Verso.Output.Html :=
  let message := "Choose a whole number of nodes from 1 to 8."
  if count < 1 || count > 8 then
    {{ <p role="alert"> {{message}} </p> }}
  else
    let ink := Color.rgb 40 85 117
    let stroke : Stroke := {color := ink, width := 2}
    let circle := PathData.circle 20
    let commands : Array (DrawCmd Empty) :=
      (List.range count).foldl (init := #[]) fun commands n =>
        let x := n.toFloat * 60
        let commands := commands
          |>.push (.pushTransform (Matrix.translate x 0))
          |>.push (.fillPath circle
            (.solid {color := Color.rgb 237 245 255}) none)
          |>.push (.strokePath circle stroke)
          |>.push (.drawTextRun (toString (n + 1))
            {fontSize := 16, color := ink} ⟨0, 0⟩)
          |>.push .popTransform
        if n + 1 < count then
          commands.push (.strokePath
            (PathData.line ⟨x + 21, 0⟩ ⟨x + 39, 0⟩) stroke)
        else commands
    let svg := Svg.render commands {
      minX := -29, minY := -29
      width := (count - 1).toFloat * 60 + 58
      height := 58
    } "chain_"
    let width := s!"width:100%;max-width:{count * 64 + 16}px;margin:1rem auto"
    {{ <section style="padding:1rem;background:#f5f8fc">
      <p style="margin:0;color:#536273">
        {{s!"{count} nodes, {count - 1} links"}}
      </p>
      <div style={{width}}>
        {{Verso.Output.Html.text false svg}}
      </div>
    </section> }}
```

Lean positions the circles, labels, and links using Illuminate drawing commands.
Illuminate renders them to SVG.
The implementation above shows the library calls. Values outside 1–8 produce a helpful message.

# Exact natural numbers

```leanRun (entry := LeanRunGate.double) (input := "21")
public def LeanRunGate.double (n : Nat) : Nat :=
  LeanRunGate.Helper.twice n
```

## Another independent greeting

```leanRun (entry := LeanRunGate.greet)
#check LeanRunGate.greet
```

# Anchored source

This example displays an anchor from the imported helper module. The displayed
definition and the compiled callable are selected separately, so the same source
region can be reused in another document without redeclaring the function.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

An ordinary anchored block can display that same source without a Run form:

```anchor twice (module := LeanRunGate.Helper) -defSite
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

The {name}`LeanRunGate.Helper.twice` reference uses the native source block's definition target.

# Typed inputs

Boolean choices and unsigned integers use the same worker lifecycle as text.
UInt64 arithmetic wraps after its maximum value, `18446744073709551615`.

```leanRunAnchor flip (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.flip)
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
```

```leanRunAnchor increment (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.increment) (input := "9007199254740993")
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
```

# Multiline text

Enter preserves line breaks. Ctrl+Enter or ⌘+Enter runs the example.

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
```

# Ordinary Lean

```lean
#check Nat.add
```

# Try Stop

This function counts up to the number you enter. Try a small number first.
Then enter `1000000000000`, choose Run, and press Stop to interrupt it.

```leanRun (entry := LeanRunGate.spin) (input := "10")
public def LeanRunGate.spinLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunGate.spinLoop n (acc + 1)

public def LeanRunGate.spin (n : Nat) : Nat :=
  LeanRunGate.spinLoop n 0
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

*The model*

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

*The transition*

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

*The view*

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
