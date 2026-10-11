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

A sequence records domain states and their labels and failures. Render that
recorded trace as HTML or text without changing its meaning.
-/
public section

namespace VersoLeanRun
open Verso.Output Lean

/-- One labelled state, optionally reporting a failure at this step. -/
structure SequenceStep (α : Type) where
  /-- The step's domain label. -/
  label : String
  /-- The model state at this step. -/
  state : α
  /-- An optional failure associated with this state. -/
  error : Option String := none

/-- A finite computation or explanation. Its state and meaning stay in Lean. -/
structure Sequence (α : Type) where
  /-- The initial observation; even an empty trace contains this state. -/
  initial : SequenceStep α
  /-- Subsequent observations, in execution order. -/
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

/-!
## Working with a trace

{name}`VersoLeanRun.Sequence` records a nonempty trace: an initial state followed
by an array of labelled steps. It stores domain states, so rendering remains a
separate choice. {name}`VersoLeanRun.Sequence.view` produces HTML observations;
{name}`VersoLeanRun.Sequence.viewText` uses the state's {name}`ToString` instance.

```lean
open VersoLeanRun

def counting : Sequence Nat :=
  Sequence.iterate Nat.succ 0 4 (fun n => s!"Step {n}")

def countingView : SequenceView := counting.viewText

def doubled : Sequence Nat := (fun n => 2 * n) <$> counting
```

{name}`VersoLeanRun.Sequence.map` supplies the standard {name}`Functor` interface
and preserves step labels and errors. Mapping changes observations, not the
recorded execution history.

## Trace size and replay

{name}`VersoLeanRun.Sequence.iterate` records the initial state and exactly the
requested number of transitions. A zero-length iteration still has its initial
observation. The browser accepts at most 128 frames, including that initial
frame. For longer or unbounded computations, use an on-demand automaton view.

{lit}`Sequence.cycleView` explicitly loops over a recorded trace,
preserving labels and errors. It repeats observations without inferring a state
transition. See the live automaton page for that adapter.

## Transport

{name}`VersoLeanRun.SequenceView.toPayload` and the {lit}`SequenceWire` namespace
are used by generated document adapters. Normal author functions return
{name}`VersoLeanRun.SequenceView`; they do not serialize JSON or construct
browser call contracts.
-/
