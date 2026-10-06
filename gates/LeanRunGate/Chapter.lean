module
public import VersoLeanRun
import LeanRunGate.Helper

open Verso Genre Manual InlineLean VersoLeanRun

set_option compiler.postponeCompile false

#doc (Manual) "Run compiled Lean" =>

Try the Lean functions shown below. Change an input, then choose Run to see the result.
Use Stop to interrupt a calculation.

# Greeting

```leanRun (entry := LeanRunGate.greet)
@[vir_export]
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

@[vir_export]
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

# Exact natural numbers

```leanRun (entry := LeanRunGate.double)
@[vir_export]
public def LeanRunGate.double (n : Nat) : Nat :=
  LeanRunGate.Helper.twice n
```

## Another independent greeting

```leanRun (entry := LeanRunGate.greet)
#check LeanRunGate.greet
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

@[vir_export]
public def LeanRunGate.spin (n : Nat) : Nat :=
  LeanRunGate.spinLoop n 0
```
