/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Sequence
public import Vir.Runtime
public section

namespace VersoLeanRun
open Lean.Vir

/-- A pure transition system, advanced one state at a time. -/
structure Automaton (α : Type) where
  initial : α
  step : α → α

namespace AutomatonWire

/-- The callback and its model stay in the worker. Only frames are transferred. -/
structure Session where
  initial : SequenceWire.Frame
  advance : RuntimeM SequenceWire.Frame

end AutomatonWire

/-- An on-demand view. Starting it allocates state owned by one worker. -/
structure AutomatonView where
  start : RuntimeM AutomatonWire.Session

private def wireFrame (label : String) (html : Verso.Output.Html)
    (error : Option String := none) : SequenceWire.Frame :=
  { label, html := html.asString, error }

/-- Keep only the current model; advancing does not retain prior frames. -/
def Automaton.view (machine : Automaton α) (render : α → Verso.Output.Html)
    (label : Nat → String := toString) : AutomatonView :=
  { start := do
      let state ← RuntimeRef.new (machine.initial, 0)
      return {
        initial := wireFrame (label 0) (render machine.initial)
        advance := do
          let (current, index) ← state.get
          let next := machine.step current
          let index := index + 1
          state.set (next, index)
          return wireFrame (label index) (render next) } }

/-- An invalid input has no model to advance. -/
def AutomatonView.error (message : String) : AutomatonView :=
  let frame := wireFrame "Input" .empty (some message)
  { start := pure { initial := frame, advance := pure frame } }

end VersoLeanRun
