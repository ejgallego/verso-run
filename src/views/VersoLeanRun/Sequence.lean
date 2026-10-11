/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Frame
public import Init.Data.List.Scan.Basic
public section

namespace VersoLeanRun
open Verso.Output Lean

/-- One labelled state, optionally reporting a failure at this step. -/
structure SequenceStep (α : Type) where
  label : String
  state : α
  error : Option String := none

/-- A finite computation or explanation. Its state and meaning stay in Lean. -/
structure Sequence (α : Type) where
  initial : SequenceStep α
  steps : Array (SequenceStep α) := #[]

/-- Transform observations while retaining their labels and failures. -/
def Sequence.map (f : α → β) (sequence : Sequence α) : Sequence β :=
  let step := fun (step : SequenceStep α) =>
    { label := step.label, state := f step.state, error := step.error : SequenceStep β }
  { initial := step sequence.initial, steps := sequence.steps.map step }

instance : Functor Sequence where
  map := Sequence.map

instance : LawfulFunctor Sequence where
  map_const := rfl
  id_map := by
    intro α sequence
    cases sequence with
    | mk initial steps =>
      cases initial
      simp [Functor.map, Sequence.map]
  comp_map := by
    intro α β γ f g sequence
    cases sequence
    simp [Functor.map, Sequence.map, Array.map_map, Function.comp_def]

/-- Record the initial state and exactly `count` applications of an automaton.
The transition is pure; labels refer to the iteration index, starting at zero. -/
def Sequence.iterate (step : α → α) (initial : α) (count : Nat)
    (label : Nat → String := toString) : Sequence α :=
  let initial : SequenceStep α := { label := label 0, state := initial }
  let frames := (List.range count).scanl (fun previous index =>
    { label := label (index + 1), state := step previous.state }) initial
  { initial, steps := frames.tail.toArray }

/-- A concrete presentation selected by the function's result type. -/
structure SequenceView where
  initial : Frame
  steps : Array Frame := #[]

/-- Report a failure before a model state exists. -/
def SequenceView.error (message : String) (label : String := "Input") : SequenceView :=
  { initial := { label, html := .empty, error := some message } }

/-- Render each state without changing the sequence's execution semantics. -/
def Sequence.view (sequence : Sequence α) (render : α → Html) : SequenceView :=
  let frame := fun (step : SequenceStep α) =>
    Frame.mk step.label (render step.state) step.error
  { initial := frame sequence.initial, steps := sequence.steps.map frame }

/-- A text observation using the model's existing `ToString` instance. -/
def Sequence.viewText [ToString α] (sequence : Sequence α) : SequenceView :=
  sequence.view fun state => .text true (toString state)

namespace SequenceWire

structure Payload where
  version : Nat
  frames : Array ViewWire.Frame
  deriving ToJson, Inhabited

/-- The presenter has a small, bounded synchronous workload. -/
def maxFrames : Nat := 128

def validate (payload : Payload) : Except String Payload := do
  unless payload.version == 1 do throw "Unsupported sequence presentation version"
  unless !payload.frames.isEmpty && payload.frames.size ≤ maxFrames do
    throw "A sequence presentation needs between 1 and 128 frames"
  return payload

end SequenceWire

/-- Generated adapters return typed data; VIR owns its boundary conversion. -/
def SequenceView.toPayload (view : SequenceView) : SequenceWire.Payload :=
  { version := 1, frames := #[view.initial.toWire] ++ view.steps.map Frame.toWire }

end VersoLeanRun
