import Starter.Chapter
import Starter.Resources
import VersoLeanRun.Publish

open Verso Genre Manual

def main := manualMain (%doc Starter.Chapter)
  (extraSteps := [VersoLeanRun.publishResources Starter.resources])
