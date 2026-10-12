/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import VersoLeanRun.Sequence
public import VersoLeanRun.Automaton

open scoped Verso.Output.Html
/-!
# Interactive Lean examples

verso-run runs selected Lean functions interactively from compiled Verso documents.
Functions can return primitive values, HTML, or richer interactive views,
including animations. HTML results use Verso's
{name (full := Verso.Output.Html)}`Html` type and can include SVG.
The experimental presenter is also written in Lean and uses DOM APIs to manage
its controls and previews; the
[rendering notes](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#rendering-and-transport)
describe this layer.

## Function results

A function can return {lit}`Html` directly. For example, this one produces a
paragraph containing a greeting. Opening {lit}`Verso.Output.Html` enables the
HTML quotation syntax; interpolated strings are escaped:

```lean
open Verso.Output Verso.Output.Html

public def greeting (name : String) : Html :=
  {{ <p> "Hello, " {{name}} "!" </p> }}
```

## Runnable document blocks

In a Verso document, put the definition inside a code fence labelled {lit}`leanRun`:

````
```leanRun (entry := greeting) (input := "Ada")
open Verso.Output Verso.Output.Html

public def greeting (name : String) : Html :=
  {{ <p> "Hello, " {{name}} "!" </p> }}
```
````

This fence adds an input field, Run and Stop buttons, and a result display alongside
the source. The {lit}`entry` argument names the function; {lit}`input` provides its
initial input without running it. The function's Lean type determines the input
control and result display. Ordinary {lit}`lean` fences display code
without Run controls.

Run blocks work in Manual, Blog, and Slides, each with its own adapter import. The
[authoring guide](https://github.com/ejgallego/verso-run/blob/main/docs/authoring.md)
shows the imports and publication setup, and lists the supported function types.

## Recorded and live views

The views library also provides helpers for presenting several frames or a
changing state. A {name (full := VersoLeanRun.Sequence)}`Sequence` contains
recorded, labelled frames that readers can browse. An
{name (full := VersoLeanRun.Automaton)}`Automaton` contains an initial state and a
transition function {lit}`α → α`; its live view provides playback controls.
A {lit}`leanRun` entry can return either model directly: HTML states retain their
markup, and other states use their {name}`ToString` instance for escaped text.
Their {lit}`view` helpers support custom HTML or SVG rendering.

Import {lit}`VersoLeanRun.Views` to use these helpers in an ordinary Lean module.

For example, this counter can provide either a recording or a live view:

```lean
open VersoLeanRun

public def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }

public def firstFive (seed : Nat) : Sequence Nat :=
  (counter seed).trace 4
```

With a seed of 10, {lit}`firstFive` records 10, 11, 12, 13, and 14. Readers can
inspect any of those five values. A block with
{lit}`leanRun (entry := counter) (input := "10")` starts at 10 and computes
another value each time they press Step, or repeatedly while Play is active.
No call to {lit}`view` is needed for this default display.

## Rendering model states

{name (full := VersoLeanRun.Sequence.view)}`Sequence.view` and
{name (full := VersoLeanRun.Automaton.view)}`Automaton.view` render model states.
The default renderer preserves HTML values and converts other values to escaped
text using {name}`ToString`. A custom renderer of type {lit}`α → Html` can produce
an HTML or SVG display:

```lean
open VersoLeanRun Verso.Output.Html

public def labelledCounter (seed : Nat) : AutomatonView :=
  (counter seed).view
    (fun value => {{ <p> "Count: " {{toString value}} </p> }})
    (fun index => s!"Step {index}")
```

{name (full := VersoLeanRun.Automaton.observe)}`Automaton.observe` accepts a
function that builds a {name (full := VersoLeanRun.Frame)}`Frame` from the step
number and model state, with a label and optional error message. The Frames page
explains this record; the other pages cover recorded sequences and live playback.

## Document integration

The function's result type determines how a {lit}`leanRun` block displays it.
{lit}`Sequence α` adds controls for browsing recorded frames; {lit}`Automaton α`
adds live playback. For custom displays, the view helpers return
{name (full := VersoLeanRun.SequenceView)}`SequenceView` or
{name (full := VersoLeanRun.AutomatonView)}`AutomatonView`, which use the same
controls. Run blocks work in Manual, Blog, and Slides documents, each with its
own adapter import.

The [demo](https://ejgallego.github.io/verso-run/) includes complete examples in
all three genres.

Opening a page leaves live examples idle. Run displays the initial state; Play
advances it continuously. Pause keeps the current state, and Stop ends the run.
Input edits remain a draft while the current computation continues; Restart
applies them. The Live automata page describes the playback controls in detail.
-/
