import LeanRunGate.Chapter
import LeanRunGate.Resources
import VersoLeanRun.Publish
import Vir.Resources.Runtime

open Verso Genre Manual

def main := manualMain (%doc LeanRunGate.Chapter)
  (extraSteps := [VersoLeanRun.publish Vir.Resources.Runtime.bundle
    #[("LeanRunGate.Chapter", LeanRunGate.resources)]])
