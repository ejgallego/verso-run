module
public import VersoLeanRun.Sequence
public import LeanRunGate.Stack
public section

namespace LeanRunSequence.Examples
open VersoLeanRun Verso.Output Verso.Output.Html

/-- Both sides of one operational step, computed by the shared Lean evaluator. -/
structure Snapshot where
  before : List Nat := []
  after : List Nat := []

def evaluate (program : String) : Sequence Snapshot := Id.run do
  let words := (program.splitOn " ").filter (!·.isEmpty)
  let mut sequence : Sequence Snapshot := { initial := {} }
  if words.isEmpty then
    return { sequence with initialError := some "Enter a program, for example: 6 7 * 2 +" }
  if words.length > 32 then
    return { sequence with initialError := some "Use at most 32 instructions." }
  let mut stack : List Nat := []
  for word in words do
    match LeanRunGate.Stack.parse word >>= fun instruction => LeanRunGate.Stack.step instruction stack with
    | .error message =>
      sequence := { sequence with steps := sequence.steps.push (SequenceStep.mk word (Snapshot.mk stack stack) (some s!"Error at '{word}': {message}")) }
      return sequence
    | .ok values =>
      if values.length > 16 || values.any (fun n => (toString n).length > 80) then
        return { sequence with steps := sequence.steps.push (SequenceStep.mk word (Snapshot.mk stack stack) (some "Stack or number limit reached.")) }
      sequence := { sequence with steps := sequence.steps.push (SequenceStep.mk word (Snapshot.mk stack values) none) }
      stack := values
  return sequence

private def stackCells (values : List Nat) : Html :=
  if values.isEmpty then {{ <p> "Empty stack" </p> }}
  else Html.fromArray <| (values.reverse.map fun n =>
    {{ <span style="display:inline-block;padding:.5rem .75rem;margin:.2rem;border:1px solid #cbd8e6;border-radius:5px;background:#edf5ff">{{toString n}}</span> }}).toArray

def renderSnapshot (snapshot : Snapshot) : Html :=
  {{ <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1rem;padding:.5rem">
    <section><h3> "Before" </h3>{{stackCells snapshot.before}}</section>
    <section><h3> "After" </h3>{{stackCells snapshot.after}}</section>
  </div> }}

-- ANCHOR: stackView
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
-- ANCHOR_END: stackView

end LeanRunSequence.Examples
