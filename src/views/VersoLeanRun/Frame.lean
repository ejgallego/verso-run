/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html

/-!
# Frames

A frame is what the reader sees at one step: a label, some HTML or SVG, and an
optional error message. Recorded sequences and live simulations use the same
frame type.
-/
public section

namespace VersoLeanRun
open Verso.Output

/-- One labelled value, with an optional error message. HTML frames describe a displayed step. -/
structure Frame (α : Type := Html) where
  /-- The heading for this step, such as “Generation 3” or “Add”. -/
  label : String
  /-- The value at this step. Displayed frames contain HTML or SVG. -/
  content : α
  /-- An error in the computation. Defaults to no error. -/
  error : Option String := none
  deriving Inhabited

/-- Transform the value, preserving its label and error message. -/
@[expose] def Frame.map (f : α → β) (frame : Frame α) : Frame β :=
  { label := frame.label, content := f frame.content, error := frame.error }

instance : Functor (fun α => Frame α) where
  map := Frame.map

instance : LawfulFunctor (fun α => Frame α) where
  map_const := rfl
  id_map := by intro α frame; cases frame; rfl
  comp_map := by intro α β γ f g frame; rfl

@[simp] theorem Frame.map_comp (f : α → β) (g : β → γ) :
    Frame.map (g ∘ f) = Frame.map g ∘ Frame.map f := rfl

@[simp] theorem Frame.map_id : Frame.map (@id α) = id := by
  funext frame
  cases frame
  rfl

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
    content := .text true s!"Value: {value}" }
```

The {lit}`content` field accepts {name}`Verso.Output.Html`, including SVG elements.
Use {name}`Verso.Output.Html.text` with {lit}`true`, as above, to escape text
rather than treat it as markup. This is especially useful for displaying reader input.

## Explain an error

Set {lit}`error` to {lit}`some message` to explain a problem in the computation,
such as a calculator instruction that needs more values on the stack. A live
simulation pauses when it reaches a frame with an error.

If the input is invalid and there is no state to display, return
{lit}`SequenceView.error` or {lit}`AutomatonView.error`. Problems loading or
running the compiled program are reported separately by verso-run.

## From computation to display

A {name}`VersoLeanRun.Frame` can hold any value. Its default content type is
{name}`Verso.Output.Html`, used for displayed steps. {name}`VersoLeanRun.Frame.map`
changes the content while keeping the label and error. HTML remains structured
through the worker and presenter; it is rendered to markup when the sandbox
preview is created.
-/
