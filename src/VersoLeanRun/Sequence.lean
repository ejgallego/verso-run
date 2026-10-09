/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html
public import Lean.Data.Json.FromToJson
public import Lean.Data.Json.Parser
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

/-- Internal transport; authors supply typed states and Html, not JSON. -/
structure Frame where
  label : String
  html : String
  error : Option String
  deriving ToJson, FromJson, Inhabited

structure Payload where
  version : Nat
  frames : Array Frame
  deriving ToJson, FromJson, Inhabited

/-- The presenter has a small, bounded synchronous workload. -/
def maxFrames : Nat := 128

def decode (text : String) : Except String Payload := do
  let payload : Payload ← Json.parse text >>= fromJson?
  unless payload.version == 1 do throw "Unsupported sequence presentation version"
  unless !payload.frames.isEmpty && payload.frames.size ≤ maxFrames do
    throw "A sequence presentation needs between 1 and 128 frames"
  return payload

/-- Preserve the existing HTML preview's script and navigation isolation. -/
def frameDocument (markup : String) : String :=
  "<!doctype html><html><head><meta charset=\"utf-8\">" ++
  "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data:\">" ++
  "<style>body{margin:0;font:16px system-ui,sans-serif;color:#1e2936;overflow-wrap:anywhere}</style>" ++
  "</head><body>" ++ markup ++ "</body></html>"

end SequenceWire

/-- Scalar VIR adapter, generated automatically for a SequenceView result. -/
def SequenceView.serialize (view : SequenceView) : String :=
  (toJson (SequenceWire.Payload.mk 1 (view.frames.map fun frame =>
    SequenceWire.Frame.mk frame.label frame.html.asString frame.error))).compress

end VersoLeanRun
