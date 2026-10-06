import LeanRunGate.Chapter
import LeanRunGate.Resources
import VersoLeanRun.Publish

open Verso Genre Manual
open Verso.Output.Html

def main := manualMain (%doc LeanRunGate.Chapter)
  (config := { extraCss := {CSS.mk (include_str "web/demo.css")} })
  (extraSteps := [VersoLeanRun.publish #[LeanRunGate.resources]])
