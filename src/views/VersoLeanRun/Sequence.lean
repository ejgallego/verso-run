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

A sequence stores labelled values in order. Its view lets readers move back and
forth through the recorded frames. A sequence can show a calculation trace,
for example, or a series of related illustrations.
-/
public section

namespace VersoLeanRun
open Verso.Output Lean

/-- A recorded sequence of states, starting with an initial state. -/
structure Sequence (α : Type) where
  /-- The first state. A sequence always contains at least this one step. -/
  initial : Frame α
  /-- The remaining steps, in order. Defaults to an empty array. -/
  steps : Array (Frame α) := #[]

/-- All recorded frames, including the initial frame. -/
@[expose] def Sequence.frames (sequence : Sequence α) : Array (Frame α) :=
  #[sequence.initial] ++ sequence.steps

/-- Apply `f` to every state, keeping the step labels and error messages. -/
def Sequence.map (f : α → β) (sequence : Sequence α) : Sequence β :=
  { initial := sequence.initial.map f, steps := sequence.steps.map (Frame.map f) }

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
    simp [Functor.map, Sequence.map, Frame.map, Array.map_map, Function.comp_def]

/-- Record `initial`, then apply `step` exactly `count` times.
The result has `count + 1` states. Labels are numbered from zero. -/
def Sequence.iterate (step : α → α) (initial : α) (count : Nat)
    (label : Nat → String := toString) : Sequence α :=
  let initial : Frame α := { label := label 0, content := initial }
  let frames := (List.range count).scanl (fun previous index =>
    { label := label (index + 1), content := step previous.content }) initial
  { initial, steps := frames.tail.toArray }

/-- A sequence of HTML frames, ready to display. -/
abbrev SequenceView := Sequence Html

/-- Display an error message when the input cannot produce a sequence. -/
def SequenceView.error (message : String) (label : String := "Input") : SequenceView :=
  { initial := { label, content := .empty, error := some message } }

/-- Draw each recorded value, preserving its label and error.
Without a renderer, keep HTML or display other values as escaped text using `ToString`. -/
def Sequence.view (sequence : Sequence α)
    (render : α → Html := by
      first | exact id | exact fun value => Verso.Output.Html.ofString (toString value)) : SequenceView :=
  sequence.map render

/-- The maximum number of displayed frames, including the initial frame. -/
def SequenceView.maxFrames : Nat := 128

/-- Check the size of a displayed sequence. Its initial frame is always present. -/
def SequenceView.validate (view : SequenceView) : Except String SequenceView := do
  unless view.steps.size < maxFrames do
    throw "A sequence presentation needs between 1 and 128 frames"
  return view

end VersoLeanRun

/-!
## Recorded states

{name (full := VersoLeanRun.Sequence.iterate)}`Sequence.iterate` records a fixed number of steps.
This example starts at zero, adds one four times, and displays the five values
0, 1, 2, 3, and 4:

```lean
open VersoLeanRun

def counting : Sequence Nat :=
  Sequence.iterate Nat.succ 0 4 (fun n => s!"Step {n}")

def doubled : Sequence Nat := (fun n => 2 * n) <$> counting
```

{name (full := VersoLeanRun.Sequence.view)}`Sequence.view` renders the recorded
values. Its default renderer preserves HTML and converts other values to escaped
text using {name}`ToString`. A custom renderer can produce an HTML or SVG display.
A {lit}`leanRun` entry can return {lit}`Sequence α` directly for this default
display. Use {lit}`sequence.view render` when the values need a custom HTML or SVG
renderer. Its result, {name (full := VersoLeanRun.SequenceView)}`SequenceView`, uses
the same navigation controls.

A {name (full := VersoLeanRun.Sequence)}`Sequence` can also be constructed directly
from an {lit}`initial` frame and an array of {lit}`steps`. Each frame has its own
label, content, and optional error message. The labels can describe individual
operations, such as “Push 3”, “Push 4”, and “Add”.

## Mapping and replay

{name (full := VersoLeanRun.Sequence.map)}`Sequence.map` applies a function to every recorded state.
Sequences also support the standard {name}`Functor` notation {lit}`<$>` used by
{lit}`doubled` above. The new sequence contains 0, 2, 4, 6, and 8, with the
original labels and error messages. Mapping does not run the computation again.

{lit}`Sequence.cycleView` replays the recorded frames continuously, returning
to the first after the last. The Live automata page describes this helper.

## Sequence length

A sequence always includes its initial state, so zero transitions still produce
one frame. The browser displays at most 128 frames, including that initial frame.
An example built with {name (full := VersoLeanRun.Sequence.iterate)}`Sequence.iterate`
can therefore display at most 127 transitions. This limit applies to the display;
the model has no fixed length limit. Oversized results are rejected rather than
shortened. Live views compute new states on demand without storing a full history.

## Rendering

{name (full := VersoLeanRun.SequenceView)}`SequenceView` is a {lit}`Sequence Html`.
Rendering changes the content of its frames while preserving their labels and
error messages. Selecting a frame displays a recorded result; it does not run
the computation again.
-/
