/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Sequence
public import Vir.Runtime

/-!
# Live automata

An automaton describes an initial state and a function that computes the next
state. Its live view provides Step, Play, Pause, and Stop controls for advancing
the computation one step at a time or playing it continuously.
-/
public section

namespace VersoLeanRun
open Lean.Vir

/-- An initial state and a function that computes its successor. -/
structure Automaton (α : Type) where
  /-- The state at the beginning of each run. -/
  initial : α
  /-- Compute the next state from the current one. -/
  step : α → α

/-- Record the initial state and `count` steps as a finite sequence.
With `count = 0`, the result contains only the initial state; `step` is not called. -/
def Automaton.trace (machine : Automaton α) (count : Nat)
    (label : Nat → String := toString) : Sequence α :=
  Sequence.iterate machine.step machine.initial count label

/-- A running computation, with its initial frame and an action that produces the next frame. -/
structure AutomatonSession where
  initial : Frame
  advance : RuntimeM Frame

/-- An action that starts a live run. -/
abbrev AutomatonView := RuntimeM AutomatonSession

/-- Choose a frame from the step number and current state.
Step zero shows the initial state; each subsequent frame follows one call to `step`. -/
def Automaton.observe (machine : Automaton α) (observe : Nat → α → Frame) : AutomatonView :=
  do
    let state ← RuntimeRef.new (machine.initial, 0)
    return {
      initial := observe 0 machine.initial
      advance := do
        let (current, index) ← state.get
        let next := machine.step current
        let index := index + 1
        state.set (next, index)
        return observe index next }

/-- Draw each state as HTML or SVG. The label function receives the step number, starting at zero. -/
def Automaton.view (machine : Automaton α)
    (render : α → Verso.Output.Html := by
      first | exact id | exact fun value => Verso.Output.Html.ofString (toString value))
    (label : Nat → String := toString) : AutomatonView :=
  machine.observe fun index state => { label := label index, content := render state }

/-- Replay a recorded sequence continuously, returning to its first step after the last.
Labels and error messages are preserved; an error disables further playback.
Each run starts at the first step; no states are recomputed. -/
def Sequence.cycleView (sequence : Sequence α)
    (render : α → Verso.Output.Html := by
      first | exact id | exact fun value => Verso.Output.Html.ofString (toString value)) : AutomatonView :=
  let observations := sequence.frames
  have nonempty : 0 < observations.size := by
    simp only [observations, Sequence.frames, Array.size_append, Array.size_singleton]
    exact Nat.add_pos_left (Nat.zero_lt_succ 0) sequence.steps.size
  let cursor : Automaton (Fin observations.size) := {
    initial := ⟨0, nonempty⟩
    step := fun index => ⟨(index.val + 1) % observations.size,
      Nat.mod_lt _ nonempty⟩ }
  cursor.observe fun _ index =>
    let observation := observations[index]
    { label := observation.label, content := render observation.content, error := observation.error }

/-- Display an error message when the input cannot start a simulation. -/
def AutomatonView.error (message : String) : AutomatonView :=
  let frame : Frame := { label := "Input", content := .empty, error := some message }
  pure { initial := frame, advance := pure frame }

end VersoLeanRun

/-!
## States and transitions

For a counter, the state is a number and each transition adds one. For Game of
Life, the state is a board and each transition computes the next generation.

The same automaton can provide a recorded sequence or a live view:

```lean
open VersoLeanRun

def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

def recorded (seed : Nat) : SequenceView :=
  ((counter seed).trace 4).view

def live (seed : Nat) : AutomatonView :=
  (counter seed).view (label := fun n => s!"Generation {n}")
```

{name (full := VersoLeanRun.Automaton.trace)}`Automaton.trace` records a fixed number
of steps that readers can browse in either direction.
{name (full := VersoLeanRun.Automaton.view)}`Automaton.view` displays the current
state and computes the next one when the reader advances. Its default renderer
preserves HTML and converts other values to escaped text using {name}`ToString`.
A custom renderer can produce HTML or SVG.

## Labels and errors

{name (full := VersoLeanRun.Automaton.observe)}`Automaton.observe` builds a frame from both the step
number and the current state. This example labels each step and reports an error
once the value exceeds 100:

```lean
open VersoLeanRun

def watched (seed : Nat) : AutomatonView :=
  ({ initial := seed, step := Nat.succ } : Automaton Nat).observe fun index state =>
    { label := s!"Step {index}"
      content := Verso.Output.Html.ofString (toString state)
      error := if state > 100 then some "Value exceeds 100" else none }
```

Step zero displays the initial state. Each advance computes the next state,
then builds its frame. An error frame displays the failure and disables Play
and Step; the reader can start a fresh run. For invalid input,
{name (full := VersoLeanRun.AutomatonView.error)}`AutomatonView.error` provides an
error view with playback disabled.

## Replaying a sequence

{name (full := VersoLeanRun.Sequence.cycleView)}`Sequence.cycleView` turns a recorded
sequence into a looping view. It accepts the same optional drawing function
as {lit}`view` and keeps the labels and errors. Playback returns to the first
step after the last, unless an error prevents further advancement. It reuses
the recorded frames, so it does not need a transition function.

## Playback and input edits

Opening a page or entering a slide leaves the example idle. Run displays the
initial state. Step advances once; Play advances repeatedly. Pause lets a step
already in progress finish, then keeps the resulting state. Stop cancels active
work and ends the run.

Input edits do not interrupt a live simulation. Restart applies the edited
input and begins again at the new initial state. If the simulation was playing,
Restart resumes playback. Pause, Stop, hiding the tab, or leaving the example
cancels that automatic resumption. Returning to the tab does not start playback.

Each example has its own state. A live run keeps only the current state and has
no fixed step limit. A model whose state grows with each step will still need
more memory over time.

## Independent runs

Two embedded copies of an example have independent state, even if both start
from the same input. Restart resets only the selected copy.
-/
