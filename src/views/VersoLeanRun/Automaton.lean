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

An automaton defines a pure transition on a Lean state. Observe it as a finite
trace or as a worker-owned session that advances one state at a time.
-/
public section

namespace VersoLeanRun
open Lean.Vir

/-- A pure transition system, advanced one state at a time. -/
structure Automaton (α : Type) where
  /-- The state used by each newly started session. -/
  initial : α
  /-- One pure transition, evaluated only when the session advances. -/
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

/-!
## Choosing a live view

An {name}`VersoLeanRun.Automaton` is a pure model: an initial state and a transition
{lit}`α → α`. It has no playback timer or browser effects. The same model can be
recorded as a finite trace with {name}`VersoLeanRun.Automaton.trace`, or advanced
on demand using {name}`VersoLeanRun.Automaton.view`.

```lean
open VersoLeanRun

def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

def recorded (seed : Nat) : SequenceView :=
  ((counter seed).trace 4).viewText

def live (seed : Nat) : AutomatonView :=
  (counter seed).viewText (fun n => s!"Generation {n}")
```

## Observations and failures

Use {name}`VersoLeanRun.Automaton.observe` when the label, markup, or failure
depends on both the iteration index and the current state. Index zero observes
the initial state; each advance applies the transition once before observing.

```lean
open VersoLeanRun

def watched (seed : Nat) : AutomatonView :=
  ({ initial := seed, step := Nat.succ } : Automaton Nat).observe fun index state =>
    { label := s!"Step {index}"
      html := .text true (toString state)
      error := if state > 100 then some "Observation limit reached" else none }
```

The live player pauses on a frame with a domain error. Input failures can return
{name}`VersoLeanRun.AutomatonView.error` before allocating a model. A model that
never terminates can continue indefinitely while retaining only its current
state; a retained growing data structure can still consume growing memory.

## Session lifetime

Each Run starts a worker-owned session from the model's initial state. Pause
retains the current state; Stop destroys the session. Play does not start on page
load or slide entry. Leaving a placement, hiding the page, or disposing the host
cancels active playback. JavaScript selects observations and schedules advances;
the transition and rendering stay in Lean.

The {lit}`AutomatonWire` session and {name}`VersoLeanRun.AutomatonView.start`
implement that execution boundary. Normal document authors return
{name}`VersoLeanRun.AutomatonView` and let the generated adapter start it.
-/
