module
public import VersoLeanRun.Sequence
public section

-- ANCHOR: stack
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
-- ANCHOR_END: stack
