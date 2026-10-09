module
public import VersoLeanRun.Sequence
public import LeanRunGate.Stack
public section

namespace LeanRunSequence.Examples
open VersoLeanRun Verso.Output Verso.Output.Html

/-- The view uses the ordinary evaluator's instruction snapshots directly. -/
abbrev Snapshot := LeanRunGate.Stack.TraceStep

def evaluate (program : String) : Sequence Snapshot :=
  let trace := LeanRunGate.Stack.evaluate program
  { initial := { label := "Start", before := [], after := [] }
    initialError := trace.initialError
    steps := trace.steps.map fun step => { label := step.label, state := step, error := step.error } }

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
