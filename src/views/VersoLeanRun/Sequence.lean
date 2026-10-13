/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Frame
public import Init.Data.List.Scan.Basic

/-!
# Finite sequences

Record the steps of a computation so readers can inspect them in either
direction. A sequence is useful for a calculator trace, a worked example, or a
short simulation with a beginning and an end.
-/
public section

namespace VersoLeanRun
open Verso.Output Lean

/-- One recorded state, with a label and an optional error message. -/
structure SequenceStep (α : Type) where
  /-- The heading for this step. -/
  label : String
  /-- The value to display at this step. -/
  state : α
  /-- An error in the computation at this step. Defaults to no error. -/
  error : Option String := none

/-- A recorded sequence of states, starting with an initial state. -/
structure Sequence (α : Type) where
  /-- The first state. A sequence always contains at least this one step. -/
  initial : SequenceStep α
  /-- The remaining steps, in order. Defaults to an empty array. -/
  steps : Array (SequenceStep α) := #[]

/-- Apply `f` to every state, keeping the step labels and error messages. -/
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

/-- Record `initial`, then apply `step` exactly `count` times.
The result has `count + 1` states. Labels are numbered from zero. -/
def Sequence.iterate (step : α → α) (initial : α) (count : Nat)
    (label : Nat → String := toString) : Sequence α :=
  let initial : SequenceStep α := { label := label 0, state := initial }
  let frames := (List.range count).scanl (fun previous index =>
    { label := label (index + 1), state := step previous.state }) initial
  { initial, steps := frames.tail.toArray }

/-- A sequence ready to display. Return this type from your example function. -/
structure SequenceView where
  /-- The first frame to display. -/
  initial : Frame
  /-- The remaining frames, in order. Defaults to an empty array. -/
  steps : Array Frame := #[]

/-- Display an error message when the input cannot produce a sequence. -/
def SequenceView.error (message : String) (label : String := "Input") : SequenceView :=
  { initial := { label, html := .empty, error := some message } }

/-- Draw each recorded state as HTML or SVG, keeping its label and error message. -/
def Sequence.view (sequence : Sequence α) (render : α → Html) : SequenceView :=
  let frame := fun (step : SequenceStep α) =>
    Frame.mk step.label (render step.state) step.error
  { initial := frame sequence.initial, steps := sequence.steps.map frame }

/-- Display each state as escaped text using its `ToString` instance. -/
def Sequence.viewText [ToString α] (sequence : Sequence α) : SequenceView :=
  sequence.view fun state => .text true (toString state)

namespace SequenceWire

structure Payload where
  version : Nat
  frames : Array ViewWire.Frame
  deriving ToJson, Inhabited

/-- The maximum number of frames in a displayed sequence, including its initial frame. -/
def maxFrames : Nat := 128

def validate (payload : Payload) : Except String Payload := do
  unless payload.version == 1 do throw "Unsupported sequence presentation version"
  unless !payload.frames.isEmpty && payload.frames.size ≤ maxFrames do
    throw "A sequence presentation needs between 1 and 128 frames"
  return payload

end SequenceWire

/-- Convert a view to the format sent to the browser. Document adapters call this for you. -/
def SequenceView.toPayload (view : SequenceView) : SequenceWire.Payload :=
  { version := 1, frames := #[view.initial.toWire] ++ view.steps.map Frame.toWire }

end VersoLeanRun

/-!
## Record and display a sequence

Use {name}`VersoLeanRun.Sequence.iterate` to record a fixed number of steps.
This example starts at zero, adds one four times, and displays the five values
0, 1, 2, 3, and 4:

```lean
open VersoLeanRun

def counting : Sequence Nat :=
  Sequence.iterate Nat.succ 0 4 (fun n => s!"Step {n}")

def countingView : SequenceView := counting.viewText

def doubled : Sequence Nat := (fun n => 2 * n) <$> counting
```

{name}`VersoLeanRun.Sequence.viewText` displays each state using {name}`ToString`.
For HTML or SVG, pass your drawing function to {name}`VersoLeanRun.Sequence.view`.
Return the resulting {name}`VersoLeanRun.SequenceView` from your example function
so readers can move between its steps.

You can also construct a {name}`VersoLeanRun.Sequence` directly: supply an
{lit}`initial` step and an array of {lit}`steps`, each with its own label, state,
and optional error message. This suits computations whose steps need different
names, such as “Push 3”, “Push 4”, and “Add”.

## Reuse the recorded states

{name}`VersoLeanRun.Sequence.map` applies a function to every recorded state.
It also supports the standard {name}`Functor` notation {lit}`<$>` used by
{lit}`doubled` above. The new sequence contains 0, 2, 4, 6, and 8, with the
original labels and error messages. Mapping does not run the computation again.

To replay the sequence continuously, use {lit}`Sequence.cycleView`, described on
the Live automata page. It displays the recorded states in order, then returns
to the first one.

## How many steps?

A sequence always includes its initial state. Asking for zero transitions
therefore produces one frame. The browser accepts at most 128 frames, so
{name}`VersoLeanRun.Sequence.iterate` can display at most 127 transitions.
For a longer simulation, use a live automaton to compute one new state at a time.

## For custom integrations

{name}`VersoLeanRun.SequenceView.toPayload` prepares the frames for sending to
the browser. The {lit}`SequenceWire` namespace defines that format and checks its
version and frame count. Document adapters handle this for you; an example
function returns {name}`VersoLeanRun.SequenceView` directly.
-/
