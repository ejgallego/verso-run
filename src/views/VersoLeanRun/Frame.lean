/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html
public import Lean.Data.Json.FromToJson

/-!
# Frames

A frame is what the reader sees at one step: a label, some HTML or SVG, and an
optional error message. Recorded sequences and live simulations use the same
frame type.
-/
public section

namespace VersoLeanRun
open Verso.Output

/-- One displayed step, with a label, HTML content, and an optional error message. -/
structure Frame where
  /-- The heading for this step, such as “Generation 3” or “Add”. -/
  label : String
  /-- The HTML or SVG to display in the isolated preview. -/
  html : Html
  /-- An error in the computation, such as stack underflow. Defaults to no error. -/
  error : Option String := none

namespace ViewWire

/-- The `ViewWire.Frame` format sent to the browser, with HTML rendered to a string. -/
structure Frame where
  label : String
  html : String
  error : Option String
  deriving Lean.ToJson, Inhabited

end ViewWire

/-- Convert a frame to the format sent to the browser. Document adapters call this for you. -/
def Frame.toWire (frame : Frame) : ViewWire.Frame :=
  { label := frame.label, html := frame.html.asString, error := frame.error }

end VersoLeanRun

/-!
## Describe a step

Build a {name}`VersoLeanRun.Frame` when you want to choose the heading, display,
and error message together. For example, a simulation might show a generation
number above a drawing of its board. This smaller example displays a number:

```lean
open VersoLeanRun Verso.Output

def snapshot (generation : Nat) (value : Nat) : Frame :=
  { label := s!"Generation {generation}"
    html := .text true s!"Value: {value}" }
```

The {lit}`html` field accepts {name}`Verso.Output.Html`, including SVG elements.
Use {name}`Verso.Output.Html.text` with {lit}`true`, as above, to escape text
rather than treat it as markup. This is especially useful for displaying reader input.

## Explain an error

Set {lit}`error` to {lit}`some message` to explain a problem in the computation,
such as a calculator instruction that needs more values on the stack. A live
simulation pauses when it reaches a frame with an error.

If the input is invalid and there is no state to display, return
{lit}`SequenceView.error` or {lit}`AutomatonView.error`. Problems loading or
running the compiled program are reported separately by verso-run.

## For custom integrations

{name}`VersoLeanRun.Frame.toWire` converts the HTML to a string in
{name}`VersoLeanRun.ViewWire.Frame` for sending to the browser. Document adapters
handle this conversion; use {name}`VersoLeanRun.Frame` when writing a display.
-/
