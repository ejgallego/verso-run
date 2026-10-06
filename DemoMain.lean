import LeanRunGate.Chapter
import LeanRunGate.Resources
import VersoLeanRun.Publish

open Verso Genre Manual

def main := manualMain (%doc LeanRunGate.Chapter)
  (extraSteps := [VersoLeanRun.publish #[LeanRunGate.resources]])
