/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import VersoLeanRun.Sequence
public import VersoLeanRun.Automaton

/-!
# View library

The view library provides optional helpers for displaying recorded states and
live computations in verso-run. Import {lit}`VersoLeanRun.Views` in an ordinary
Lean module; it does not require a document or publication setup.

The [user guide](../guide/) covers runnable functions, HTML results, and document
setup for Manual, Blog, and Slides. This reference explains the view types,
their operations, and custom rendering, with Lean-checked examples.

## Recorded and live views

A {name (full := VersoLeanRun.Sequence)}`Sequence` stores labelled frames that
readers can browse in either direction. An
{name (full := VersoLeanRun.Automaton)}`Automaton` describes an initial state and
a transition {lit}`α → α`; its live view computes a new state on each advance.
For example, one counter can provide either a live computation or a recording:

```lean
open VersoLeanRun

public def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

public def firstFive (seed : Nat) : Sequence Nat :=
  (counter seed).trace 4
```

With a seed of 10, {lit}`firstFive` records 10, 11, 12, 13, and 14.
{lit}`counter` can keep advancing without recording the earlier values.

The [Finite sequences](VersoLeanRun/Sequence/) page covers constructing,
mapping, and rendering recordings. [Live automata](VersoLeanRun/Automaton/)
covers transitions, observations, and cyclic replay. Both use
[Frames](VersoLeanRun/Frame/) to pair content with labels and optional errors.

## Runnable document blocks

In a document that imports the module containing {lit}`counter`, this
{lit}`leanRun` fence adds an input field and playback controls:

````
```leanRun (entry := counter) (input := "10")
#check counter
```
````

The {lit}`entry` argument names the function; {lit}`input` sets the initial input
without running it. Returning a {lit}`Sequence α` instead provides controls for
browsing recorded frames. The [authoring guide](../guide/authoring/)
shows a complete chapter, the supported function types, and publication setup.
It also explains the browser controls and the lifetime of a run.

## Custom displays

A {lit}`leanRun` entry can return either model directly. HTML states retain their
markup; other states use their {name}`ToString` instance for escaped text.
For custom HTML or SVG, {name (full := VersoLeanRun.Sequence.view)}`Sequence.view`
and {name (full := VersoLeanRun.Automaton.view)}`Automaton.view` accept a renderer
of type {lit}`α → Lean.Html`. They return
{name (full := VersoLeanRun.SequenceView)}`SequenceView` and
{name (full := VersoLeanRun.AutomatonView)}`AutomatonView`, respectively.
The individual reference pages show these operations in context.
-/
