import LeanRunTyped.Examples
import Lean.Data.Json

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-typed-oracle flip|increment|lines INPUT"
  let result ← match role with
    | "flip" =>
      if input == "true" || input == "false" then
        pure <| toString <| LeanRunTyped.Examples.flip (input == "true")
      else throw <| IO.userError "invalid Bool"
    | "increment" => do
      let some value := input.toNat? | throw <| IO.userError "invalid UInt64"
      if value > 18446744073709551615 then throw <| IO.userError "UInt64 out of range"
      pure <| toString <| LeanRunTyped.Examples.increment value.toUInt64
    | "lines" => pure <| LeanRunTyped.Examples.lines input
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
