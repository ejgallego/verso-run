import LeanRunGate.Chapter
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import Lean.Data.Json

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-oracle greet|stack|sequence|life|htmlGreeting|diagram|badge|wordSteps|double|spin INPUT"
  let result ← match role with
    | "greet" => pure <| LeanRunGate.greet input
    | "sequence" => pure <| (Lean.toJson (LeanRunSequence.Examples.stackView input).toPayload).compress
    | "life" => pure <| (Lean.toJson (LeanRunSequence.Life.lifeView input).toPayload).compress
    | "stack" => pure <| LeanRunGate.Stack.run input
    | "htmlGreeting" => pure <| (LeanRunGate.htmlGreeting input).asString
    | "diagram" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| (LeanRunGate.diagram n).asString
    | "badge" =>
      if input == "true" || input == "false" then
        pure <| (LeanRunRendered.Examples.badge (input == "true")).asString
      else throw <| IO.userError "invalid Bool"
    | "wordSteps" => do
      let some n := input.toNat? | throw <| IO.userError "invalid UInt64"
      if n > 18446744073709551615 then throw <| IO.userError "UInt64 out of range"
      pure <| (Lean.toJson (LeanRunRendered.Examples.wordSteps n.toUInt64).toPayload).compress
    | "double" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.double n)
    | "spin" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.spin n)
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
