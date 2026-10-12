/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import VersoLeanRun.Sequence
public import VersoLeanRun.Automaton

/-!
# Interactive Lean examples

Use verso-run to let readers explore a computation: step through a calculator,
watch a Game of Life board evolve, or compare a few successive values. Define
the computation and its display in Lean; verso-run adds the browser controls.

Import {lit}`VersoLeanRun.Views` in the module containing your computation.
Start with text output, then add an HTML or SVG drawing when it helps explain
what is happening.

## Record a few steps or keep running?

Choose a {name (full := VersoLeanRun.Sequence)}`Sequence` when readers should be able to move back and forth through
a fixed set of states. Choose an {name (full := VersoLeanRun.Automaton)}`Automaton` when each step should compute the next state,
as in a simulation. An automaton needs an initial value and a function {lit}`α → α`
that advances it once.

This counter supports both kinds of interaction:

```lean
open VersoLeanRun

def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

def firstFive (seed : Nat) : SequenceView :=
  ((counter seed).trace 4).view

def forever (seed : Nat) : AutomatonView :=
  (counter seed).view
```

With a seed of 10, {lit}`firstFive` records 10, 11, 12, 13, and 14. Readers can
inspect any of those five values. {lit}`forever` starts at 10 and computes another
value each time they press Step, or repeatedly while Play is active.

## Draw the state

{lit}`view` displays a value using its {name}`ToString` instance. To draw it,
pass a function returning {name}`Verso.Output.Html` to
{name (full := VersoLeanRun.Sequence.view)}`Sequence.view` or {name (full := VersoLeanRun.Automaton.view)}`Automaton.view`.
Both accept HTML or SVG and display it in an isolated preview.

```lean
open VersoLeanRun

def labelledCounter (seed : Nat) : AutomatonView :=
  ({ initial := seed, step := Nat.succ } : Automaton Nat).view
    (fun value => .text true s!"Count: {value}")
    (fun index => s!"Step {index}")
```

For a display with its own label or error message, return a
{name (full := VersoLeanRun.Frame)}`Frame` from {name (full := VersoLeanRun.Automaton.observe)}`Automaton.observe`.
The Frames page explains how to build one. The finite sequence and live automaton
pages show how to adapt a model, repeat a recorded sequence, and report errors.

## Put the example in a document

Return {name (full := VersoLeanRun.SequenceView)}`SequenceView` or {name (full := VersoLeanRun.AutomatonView)}`AutomatonView` from the function you want readers to call.
Select that function with the {lit}`entry` argument of a {lit}`leanRun` block.
This works in a Manual, Blog, or Slides document. The
computation module imports {lit}`VersoLeanRun.Views`; the document imports the
adapter for its genre.

Follow the [authoring guide](https://github.com/ejgallego/verso-run/blob/main/docs/authoring.md)
to add a block to your document, or explore the
[demo](https://ejgallego.github.io/verso-run/) for complete examples.

A live example waits for Run and Play; opening the page does not start it.
Pause keeps the current state, and Stop ends the run. Editing the input lets
readers prepare a new seed while the current simulation continues; Restart
applies those edits. See Live automata for the full playback behavior.
-/
