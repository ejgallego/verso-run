module
public import VersoLeanRun.Views
public section
namespace LeanRunRendered.Examples
open VersoLeanRun Verso.Output

-- ANCHOR: badge
public def badge (enabled : Bool) : Html :=
  html%{<p><strong>{if enabled then "Enabled" else "Disabled"}</strong></p>}
-- ANCHOR_END: badge

-- ANCHOR: wordSteps
public def wordSteps (seed : UInt64) : SequenceView :=
  let machine : Automaton UInt64 := { initial := seed, step := (· + 1) }
  (machine.trace 1 (fun i => if i == 0 then "Start" else "Increment")).view
    fun word => html%{<p>Exact word: {toString word}</p>}
-- ANCHOR_END: wordSteps

-- ANCHOR: wordCycle
public def wordCycle (seed : UInt64) : AutomatonView :=
  let machine : Automaton UInt64 := { initial := seed, step := (· + 1) }
  (machine.trace 1 (fun i => if i == 0 then "Start" else "Increment")).cycleView
    fun word => html%{<p>Exact word: {toString word}</p>}
-- ANCHOR_END: wordCycle

end LeanRunRendered.Examples
