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

verso-run makes compiled Lean functions runnable in Verso documents. You select
the function; readers supply an input and see its result. A function can return
a supported scalar value for text output or Verso's
{name (full := Verso.Output.Html)}`Html` for an HTML or SVG display.

## Function results

For a single result, return its value directly. This function produces an HTML
paragraph containing a greeting:

```lean
open Verso.Output

public def greeting (name : String) : Html :=
  .tag "p" #[] (Html.ofString s!"Hello, {name}!")
```

Select {lit}`greeting` directly with {lit}`entry` in a {lit}`leanRun` block. Its Lean type
determines the input control and result display. The
[authoring guide](https://github.com/ejgallego/verso-run/blob/main/docs/authoring.md#the-result-type-chooses-the-display)
lists the supported function types and shows how to add a block to a document.

## Recorded and live views

The views library also provides helpers for presenting several frames or a
changing state. A {name (full := VersoLeanRun.Sequence)}`Sequence` contains
recorded, labelled frames that readers can browse. An
{name (full := VersoLeanRun.Automaton)}`Automaton` contains an initial state and a
transition function {lit}`α → α`; its live view provides playback controls.
Both support custom HTML or SVG rendering.

Import {lit}`VersoLeanRun.Views` to use these helpers in an ordinary Lean module.

For example, this counter can provide either a recording or a live view:

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

## Rendering model states

{lit}`view` keeps HTML values and displays other values as escaped text using
their {name}`ToString` instance. To draw a state,
pass a function returning {name}`Verso.Output.Html` to
{name (full := VersoLeanRun.Sequence.view)}`Sequence.view` or {name (full := VersoLeanRun.Automaton.view)}`Automaton.view`.
Both accept HTML or SVG and display it in an isolated preview.

```lean
open VersoLeanRun

def labelledCounter (seed : Nat) : AutomatonView :=
  ({ initial := seed, step := Nat.succ } : Automaton Nat).view
    (fun value => Verso.Output.Html.ofString s!"Count: {value}")
    (fun index => s!"Step {index}")
```

For a display with its own label or error message, return a
{name (full := VersoLeanRun.Frame)}`Frame` from {name (full := VersoLeanRun.Automaton.observe)}`Automaton.observe`.
The Frames page explains how to build one. The finite sequence and live automaton
pages show how to adapt a model, repeat a recorded sequence, and report errors.

## Document integration

To display a single result, a recorded sequence, or a live view, select its
function with the {lit}`entry` argument of a {lit}`leanRun` block. Return
{name (full := VersoLeanRun.SequenceView)}`SequenceView` for sequence controls or
{name (full := VersoLeanRun.AutomatonView)}`AutomatonView` for live playback.
The block works in Manual, Blog, and Slides documents; each document imports
the adapter for its genre.

Follow the [authoring guide](https://github.com/ejgallego/verso-run/blob/main/docs/authoring.md)
to add a block to your document, or explore the
[demo](https://ejgallego.github.io/verso-run/) for complete examples.

A live example waits for Run and Play; opening the page does not start it.
Pause keeps the current state, and Stop ends the run. Editing the input lets
readers prepare a new seed while the current simulation continues; Restart
applies those edits. See Live automata for the full playback behavior.
-/
