/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import VersoLeanRun.Sequence
public import VersoLeanRun.Automaton

/-!
# Lean models, interactive views

Import {lit}`VersoLeanRun.Views` in a normal Lean module. It provides finite sequences,
pure transition systems, and HTML observations. Your Lean code owns the states,
transitions, labels, and failures; the browser provides controls and presents
the observations.

## Finite or live?

Use {name (full := VersoLeanRun.Sequence)}`Sequence` for a bounded trace whose states are already recorded.
Use {name (full := VersoLeanRun.Automaton)}`Automaton` for a pure transition {lit}`α → α`, then choose a finite trace
or a live view of that same model:

```lean
open VersoLeanRun

def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

def firstFive (seed : Nat) : SequenceView :=
  ((counter seed).trace 4).viewText

def forever (seed : Nat) : AutomatonView :=
  (counter seed).viewText
```

The finite trace includes the initial state and four transitions. The live view
retains one current state and advances on demand. Creating a view does not start
playback: Run creates a session; Play advances it until Pause, Stop, a reported
failure, or a visibility change. Reloading the page starts idle.

## Rendering and domain-specific observations

{lit}`viewText` uses an existing {name}`ToString` instance. Use {name (full := VersoLeanRun.Sequence.view)}`Sequence.view` or
{name (full := VersoLeanRun.Automaton.view)}`Automaton.view` when your state has an HTML or SVG presentation. Both take
a renderer {lit}`α → Verso.Output.Html`; markup is displayed in an isolated preview.
For labels and failures that depend on the state, use {name (full := VersoLeanRun.Automaton.observe)}`Automaton.observe`
and return a {name (full := VersoLeanRun.Frame)}`Frame`.

{name (full := VersoLeanRun.Sequence.map)}`Sequence.map` changes recorded states while preserving labels and failures.
{name (full := VersoLeanRun.Automaton.trace)}`Automaton.trace` records transitions using the standard library's {name}`List.scanl`.
{name (full := VersoLeanRun.Sequence.cycleView)}`Sequence.cycleView` repeats recorded observations explicitly; it does not
recover an underlying transition from a trace.

## Using a view in a document

An author function returning {name (full := VersoLeanRun.SequenceView)}`SequenceView` or {name (full := VersoLeanRun.AutomatonView)}`AutomatonView` can be
selected by {lit}`entry` in a {lit}`leanRun` or {lit}`leanRun'` block in Manual, Blog, or Slides.
Keep the model module's import as {lit}`VersoLeanRun.Views`; the document imports its
genre adapter. See the [authoring guide](https://github.com/ejgallego/verso-run/blob/main/docs/authoring.md)
for block arguments and the [demo](https://ejgallego.github.io/verso-run/)
for runnable examples.

The {lit}`ViewWire`, {lit}`SequenceWire`, and {lit}`AutomatonWire` namespaces describe the
execution boundary. Normal authors return views and let the document adapter
construct the compiler-checked call contract.
-/
