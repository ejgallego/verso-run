module
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
-- ANCHOR_END: stack
