import LeanRunGate.Chapter
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import Lean.Data.Json


-- Render native reference observations for browser comparison, independently of
-- the structured VIR transport. This is test output, not an executable ABI.
def referenceFrame (frame : VersoLeanRun.Frame) : Lean.Json :=
  Lean.Json.mkObj [("label", Lean.toJson frame.label),
    ("html", Lean.toJson frame.content.render), ("error", Lean.toJson frame.error)]

def referenceSequence (view : VersoLeanRun.SequenceView) : Lean.Json :=
  Lean.Json.mkObj [("frames", Lean.toJson (view.frames.map referenceFrame))]

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-oracle greet|stack|sequence|life|htmlGreeting|diagram|badge|wordSteps|wordCycle|double|spin INPUT"
  let result ← match role with
    | "greet" => pure <| LeanRunGate.greet input
    | "sequence" => pure <| (referenceSequence (LeanRunSequence.Examples.stackView input)).compress
    | "life" => do
      let session ← Lean.Vir.RuntimeM.run (LeanRunSequence.Life.lifeView input)
      let mut frames := #[session.initial]
      for _ in [:140] do
        frames := frames.push (← Lean.Vir.RuntimeM.run session.advance)
      pure <| (Lean.toJson (frames.map referenceFrame)).compress
    | "stack" => pure <| LeanRunGate.Stack.run input
    | "htmlGreeting" => pure <| (LeanRunGate.htmlGreeting input).render
    | "diagram" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| (LeanRunGate.diagram n).render
    | "badge" =>
      if input == "true" || input == "false" then
        pure <| (LeanRunRendered.Examples.badge (input == "true")).render
      else throw <| IO.userError "invalid Bool"
    | "wordSteps" => do
      let some n := input.toNat? | throw <| IO.userError "invalid UInt64"
      if n > 18446744073709551615 then throw <| IO.userError "UInt64 out of range"
      pure <| (referenceSequence (LeanRunRendered.Examples.wordSteps n.toUInt64)).compress
    | "wordCycle" => do
      let some n := input.toNat? | throw <| IO.userError "invalid UInt64"
      if n > 18446744073709551615 then throw <| IO.userError "UInt64 out of range"
      let session ← Lean.Vir.RuntimeM.run (LeanRunRendered.Examples.wordCycle n.toUInt64)
      let mut frames := #[session.initial]
      for _ in [:5] do
        frames := frames.push (← Lean.Vir.RuntimeM.run session.advance)
      pure <| (Lean.toJson (frames.map referenceFrame)).compress
    | "double" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.double n)
    | "spin" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.spin n)
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
