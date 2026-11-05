import Consumer.Chapter
import Consumer.Resources
import VersoLeanRun.Publish
import Presenter

open Verso Genre Manual

def main := manualMain (%doc Consumer.Chapter)
  (extraSteps := [VersoLeanRun.publish Consumer.resources (presenters := #[Consumer.presenter])])
