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
  initial : α
  steps : Array (SequenceStep α) := #[]
  initialLabel : String := "Start"
  initialError : Option String := none

/-- A state rendered with Verso's existing HTML API. -/
structure SequenceFrame where
  label : String
  html : Html
  error : Option String := none

/-- A concrete presentation selected by the function's result type. -/
structure SequenceView where
  frames : Array SequenceFrame

/-- Render each state without changing the sequence's execution semantics. -/
def Sequence.view (sequence : Sequence α) (render : α → Html) : SequenceView :=
  let initial := SequenceFrame.mk sequence.initialLabel (render sequence.initial) sequence.initialError
  { frames := #[initial] ++ sequence.steps.map fun step =>
      SequenceFrame.mk step.label (render step.state) step.error }

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
  { version := 1, frames := view.frames.map fun frame =>
    { label := frame.label, html := frame.html.asString, error := frame.error } }

end VersoLeanRun
