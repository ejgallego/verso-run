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

def countingView : SequenceView := counting.view

def doubled : Sequence Nat := (fun n => 2 * n) <$> counting
```

{name (full := VersoLeanRun.Sequence.view)}`Sequence.view` displays these numbers
as escaped text using {name}`ToString`. Values that are already HTML stay HTML.
For another kind of state, pass a drawing function returning HTML or SVG.
Return the resulting {name (full := VersoLeanRun.SequenceView)}`SequenceView` from your example function
so readers can move between its steps.

You can also construct a {name (full := VersoLeanRun.Sequence)}`Sequence` directly: supply an
{lit}`initial` frame and an array of {lit}`steps`, each with its own label, content,
and optional error message. This suits computations whose steps need different
names, such as “Push 3”, “Push 4”, and “Add”.

## Mapping and replay

{name (full := VersoLeanRun.Sequence.map)}`Sequence.map` applies a function to every recorded state.
It also supports the standard {name}`Functor` notation {lit}`<$>` used by
{lit}`doubled` above. The new sequence contains 0, 2, 4, 6, and 8, with the
original labels and error messages. Mapping does not run the computation again.

To replay the sequence continuously, use {lit}`Sequence.cycleView`, described on
the Live automata page. It displays the recorded states in order, then returns
to the first one.

## Sequence length

A sequence always includes its initial state. Asking for zero transitions
therefore produces one frame. The browser accepts at most 128 frames, so
an example built with {name (full := VersoLeanRun.Sequence.iterate)}`Sequence.iterate`
can display at most 127 transitions. The recording itself has no such limit;
larger results are rejected when displayed, rather than silently shortened.
For a longer simulation, use a live automaton to compute one new state at a time.

## Rendering

{name (full := VersoLeanRun.SequenceView)}`SequenceView` is a {lit}`Sequence Html`.
Rendering changes the content of its frames while preserving their labels and
error messages. Selecting a frame displays a recorded result; it does not run
the computation again.
-/
