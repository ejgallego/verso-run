import LeanRunBlog.Examples
import LeanRunGate.Helper
import Lean.Data.Json

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-blog-oracle greet|card|count|twice INPUT"
  let result ← match role with
    | "greet" => pure <| LeanRunBlog.Examples.greet input
    | "card" => pure <| LeanRunBlog.Examples.card input
    | "count" | "twice" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString <| if role == "count" then LeanRunBlog.Examples.count n else LeanRunGate.Helper.twice n
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
