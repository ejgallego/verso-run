import LeanRunGate.Chapter
import Lean.Data.Json

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-oracle greet|stack|htmlGreeting|diagram|double|spin INPUT"
  let result ← match role with
    | "greet" => pure <| LeanRunGate.greet input
    | "stack" => pure <| LeanRunGate.Stack.run input
    | "htmlGreeting" => pure <| (LeanRunGate.htmlGreeting input).asString
    | "diagram" => pure <| (LeanRunGate.diagram input).asString
    | "double" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.double n)
    | "spin" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString (LeanRunGate.spin n)
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
