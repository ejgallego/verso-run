module
public import VersoLeanRun.Sequence
public section
namespace LeanRunRendered.Examples
open VersoLeanRun Verso.Output Verso.Output.Html

-- ANCHOR: badge
public def badge (enabled : Bool) : Html :=
  {{ <p><strong>{{if enabled then "Enabled" else "Disabled"}}</strong></p> }}
-- ANCHOR_END: badge

-- ANCHOR: wordSteps
public def wordSteps (seed : UInt64) : SequenceView :=
  let sequence : Sequence UInt64 := {
    initial := { label := "Start", state := seed }
    steps := #[{ label := "Increment", state := seed + 1 }] }
  sequence.view fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
-- ANCHOR_END: wordSteps

end LeanRunRendered.Examples
