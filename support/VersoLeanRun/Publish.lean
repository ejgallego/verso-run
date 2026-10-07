/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun
public import VersoLeanRun.Collect
public import VersoLeanRun.Publication

public section
open Verso Genre Manual

namespace VersoLeanRun

private def decodeExperiment (container : Manual.Block) : Except String (Option Experiment) := do
  if container.name == `VersoLeanRun.Block.leanRun then
    return some (← Lean.fromJson? container.data)
  return none

/-- Manual output adapter; the common planner validates all bindings before writing. -/
def publish (programs : Array Vir.Resources.Bundle)
    (runtime : Vir.Resources.Bundle := Vir.Resources.Runtime.bundle) : ExtraStep := fun mode config _ text => do
  let rendered ← IO.ofExcept <| experiments decodeExperiment text
  let publication ← IO.ofExcept <| preparePublication rendered programs runtime
  let output := config.destination / (match mode with | .single => "html-single" | .multi => "html-multi")
  writePublication output publication

end VersoLeanRun
