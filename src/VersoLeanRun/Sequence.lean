/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html
public import Lean.Data.Json.FromToJson
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

/-- Record the initial state and exactly `count` applications of an automaton.
The transition is pure; labels refer to the iteration index, starting at zero. -/
def Sequence.iterate (step : α → α) (initial : α) (count : Nat)
    (label : Nat → String := toString) : Sequence α := Id.run do
  let mut state := initial
  let mut steps := #[]
  for i in [:count] do
    state := step state
    steps := steps.push { label := label (i + 1), state }
  return { initial := { label := label 0, state := initial }, steps }

/-- A state rendered with Verso's existing HTML API. -/
structure SequenceFrame where
  label : String
  html : Html
  error : Option String := none

/-- A concrete presentation selected by the function's result type. -/
structure SequenceView where
  initial : SequenceFrame
  steps : Array SequenceFrame := #[]

/-- Report a failure before a model state exists. -/
def SequenceView.error (message : String) (label : String := "Input") : SequenceView :=
  { initial := { label, html := .empty, error := some message } }

/-- Render each state without changing the sequence's execution semantics. -/
def Sequence.view (sequence : Sequence α) (render : α → Html) : SequenceView :=
  let frame := fun (step : SequenceStep α) =>
    SequenceFrame.mk step.label (render step.state) step.error
  { initial := frame sequence.initial, steps := sequence.steps.map frame }

namespace SequenceWire

/-- Typed VIR transport; authors supply states and Html. -/
structure Frame where
  label : String
  html : String
  error : Option String
  deriving ToJson, Inhabited

structure Payload where
  version : Nat
  frames : Array Frame
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
  let frame := fun (frame : SequenceFrame) =>
    ({ label := frame.label, html := frame.html.asString, error := frame.error } : SequenceWire.Frame)
  { version := 1, frames := #[frame view.initial] ++ view.steps.map frame }

end VersoLeanRun
