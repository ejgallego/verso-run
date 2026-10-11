import Consumer.Model
import Lean.Data.Json

open Lean

def main : IO Unit := do
  let mut cases := #[]
  for seed in #[0, 7, 9007199254740993, 18446744073709551615] do
    let session ← Lean.Vir.RuntimeM.run (Consumer.live seed).start
    let other ← Lean.Vir.RuntimeM.run (Consumer.live seed).start
    let mut frames := #[session.initial]
    for _ in [:5] do frames := frames.push (← Lean.Vir.RuntimeM.run session.advance)
    cases := cases.push <| Json.mkObj [
      ("seed", toJson (toString seed)),
      ("scalar", toJson (toString (Consumer.increment seed))),
      ("finite", toJson (Consumer.finite seed).toPayload),
      ("live", toJson frames),
      ("independent", toJson (← Lean.Vir.RuntimeM.run other.advance))]
  IO.println (toJson cases).compress
