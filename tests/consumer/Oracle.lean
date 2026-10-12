import Consumer.Model
import Lean.Data.Json

open Lean


-- Render native reference observations for browser comparison, independently of
-- the structured VIR transport. This is test output, not an executable ABI.
def referenceFrame (frame : VersoLeanRun.Frame) : Lean.Json :=
  Lean.Json.mkObj [("label", Lean.toJson frame.label),
    ("html", Lean.toJson frame.content.asString), ("error", Lean.toJson frame.error)]

def referenceSequence (view : VersoLeanRun.SequenceView) : Lean.Json :=
  Lean.Json.mkObj [("frames", Lean.toJson (view.frames.map referenceFrame))]

def main : IO Unit := do
  let mut cases := #[]
  for seed in #[0, 7, 9007199254740993, 18446744073709551615] do
    let session ← Lean.Vir.RuntimeM.run (Consumer.live seed)
    let other ← Lean.Vir.RuntimeM.run (Consumer.live seed)
    let mut frames := #[session.initial]
    for _ in [:5] do frames := frames.push (← Lean.Vir.RuntimeM.run session.advance)
    cases := cases.push <| Json.mkObj [
      ("seed", toJson (toString seed)),
      ("scalar", toJson (toString (Consumer.increment seed))),
      ("finite", referenceSequence (Consumer.finite seed)),
      ("live", toJson (frames.map referenceFrame)),
      ("independent", referenceFrame (← Lean.Vir.RuntimeM.run other.advance))]
  IO.println (toJson cases).compress
