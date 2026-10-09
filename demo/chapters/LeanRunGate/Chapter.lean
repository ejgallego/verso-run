module
public import VersoLeanRun
import LeanRunGate.Helper
import LeanRunTyped.Examples
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

```leanRun (entry := LeanRunGate.greet)
public def LeanRunGate.greet (name : String) : String :=
  "Hello, " ++ name
```

# Stack calculator

Write a little program with numbers and operations separated by spaces.
Run the supplied `6 7 * 2 +` program to compute `(6 × 7) + 2` and see each step.
Open the implementation to explore its Lean instruction type, parser, and execution rules.

```leanRun (entry := LeanRunGate.Stack.run) (input := "6 7 * 2 +") +collapsed
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

public def run (program : String) : String := Id.run do
  let words := (program.splitOn " ").filter (!·.isEmpty)
  if words.isEmpty then return "Enter a program, for example: 6 7 * 2 +"
  if words.length > 32 then return "Use at most 32 instructions."
  let mut stack : List Nat := []
  let mut trace := #["Start: []"]
  for word in words do
    let next := parse word >>= fun instruction => step instruction stack
    match next with
    | .error message =>
        return "\n".intercalate (trace.toList ++ [s!"Error at '{word}': {message}"])
    | .ok values =>
        if values.length > 16 || values.any (fun n => (toString n).length > 80) then
          return "\n".intercalate (trace.toList ++ ["Stack or number limit reached."])
        stack := values
        trace := trace.push s!"{word}  →  {showStack stack}"
  let result := match stack with
    | [n] => s!"Result: {n}"
    | _ => "Finish with exactly one value on the stack."
  return "\n".intercalate trace.toList ++ "\n\n" ++ result

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

# HTML greeting

Lean can also return HTML. Change the name and run this example to build a small greeting card.
The function returns Verso's `Html` type. The form serializes it for the HTML preview,
and interpolated text is escaped automatically.

```leanRun (entry := LeanRunGate.htmlGreeting) (input := "Ada") +collapsed
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

```leanRun (entry := LeanRunGate.htmlGreeting) (input := "Ada\nGrace") +multiline +collapsed
#check LeanRunGate.htmlGreeting
```

# Illuminate diagrams

Choose a number from 1 to 8, then Run to build a chain of numbered nodes.
Try `1`, `4`, and `8`: the labels, links, and layout are computed by Lean in your browser.

```leanRun (entry := LeanRunGate.diagram) (input := "4") +collapsed
open Illuminate Verso.Output.Html

public def LeanRunGate.diagram (input : String) : Verso.Output.Html :=
  let message := "Choose a whole number of nodes from 1 to 8."
  match input.toNat? with
  | none => {{ <p role="alert"> {{message}} </p> }}
  | some count =>
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
Open the implementation to see the library calls. Values outside 1–8 produce a helpful message.

# Exact natural numbers

```leanRun (entry := LeanRunGate.double)
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

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline +collapsed
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

```leanRun (entry := LeanRunGate.spin)
public def LeanRunGate.spinLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunGate.spinLoop n (acc + 1)

public def LeanRunGate.spin (n : Nat) : Nat :=
  LeanRunGate.spinLoop n 0
```
