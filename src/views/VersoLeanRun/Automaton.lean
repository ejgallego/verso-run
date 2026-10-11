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

/-- Observe the initial state and exactly `count` transitions as a finite trace.
Zero transitions never call `step`; this does not start a live session. -/
def Automaton.trace (machine : Automaton α) (count : Nat)
    (label : Nat → String := toString) : Sequence α :=
  Sequence.iterate machine.step machine.initial count label

namespace AutomatonWire

/-- The callback and its model stay in the worker. Only frames are transferred. -/
structure Session where
  initial : ViewWire.Frame
  advance : RuntimeM ViewWire.Frame

end AutomatonWire

/-- An on-demand view. Starting it allocates state owned by one worker. -/
structure AutomatonView where
  start : RuntimeM AutomatonWire.Session

/-- Observe a live model, including domain-specific labels and failures.
The iteration index starts at zero; only the current model is retained. -/
def Automaton.observe (machine : Automaton α) (observe : Nat → α → Frame) : AutomatonView :=
  { start := do
      let state ← RuntimeRef.new (machine.initial, 0)
      return {
        initial := (observe 0 machine.initial).toWire
        advance := do
          let (current, index) ← state.get
          let next := machine.step current
          let index := index + 1
          state.set (next, index)
          return (observe index next).toWire } }

/-- Render a live model without changing its transition semantics. -/
def Automaton.view (machine : Automaton α) (render : α → Verso.Output.Html)
    (label : Nat → String := toString) : AutomatonView :=
  machine.observe fun index state => { label := label index, html := render state }

/-- A text observation using the model's existing `ToString` instance. -/
def Automaton.viewText [ToString α] (machine : Automaton α)
    (label : Nat → String := toString) : AutomatonView :=
  machine.view (fun state => .text true (toString state)) label

/-- Repeat a recorded trace explicitly, retaining its labels and failures.
This repeats observations rather than reconstructing an underlying transition.
An error frame still pauses the live player. Run owns a fresh replay cursor. -/
def Sequence.cycleView (sequence : Sequence α) (render : α → Verso.Output.Html) : AutomatonView :=
  let observations := #[sequence.initial] ++ sequence.steps
  have nonempty : 0 < observations.size := by
    simp only [observations, Array.size_append, Array.size_singleton]
    exact Nat.add_pos_left (Nat.zero_lt_succ 0) sequence.steps.size
  let cursor : Automaton (Fin observations.size) := {
    initial := ⟨0, nonempty⟩
    step := fun index => ⟨(index.val + 1) % observations.size,
      Nat.mod_lt _ nonempty⟩ }
  cursor.observe fun _ index =>
    let observation := observations[index]
    { label := observation.label, html := render observation.state, error := observation.error }

/-- An invalid input has no model to advance. -/
def AutomatonView.error (message : String) : AutomatonView :=
  let frame := ({ label := "Input", html := .empty, error := some message } : Frame).toWire
  { start := pure { initial := frame, advance := pure frame } }

end VersoLeanRun
