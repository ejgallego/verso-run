import LeanRunGate.Chapter
import LeanRunGate.Resources
import LeanRunGate.HelperResources
import VersoLeanRun.Publish

open Verso Genre Manual

/-- Exercise public registration with real embedded bundles, using the normal generator. -/
def main (args : List String) : IO UInt32 := do
  let mode :: options := args
    | throw <| IO.userError "usage: lean-run-publication-check duplicate|missing [MANUAL OPTIONS]"
  let programs ← match mode with
    | "duplicate" => pure #[LeanRunGate.resources, LeanRunGate.resources,
        LeanRunGate.helperResources, LeanRunGate.helperResources]
    | "missing" => pure #[]
    | _ => throw <| IO.userError s!"unknown publication check {mode}"
  manualMain (%doc LeanRunGate.Chapter) (options := options)
    (extraSteps := [VersoLeanRun.publish programs])
