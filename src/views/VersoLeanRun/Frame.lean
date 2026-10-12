/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html

/-!
# Frames

A frame pairs a value with a label and an optional error message. Recorded
sequences and live simulations both use frames. The value can be a model state,
such as a number or a board, or HTML ready to display.
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
## Labels and content

A {name (full := VersoLeanRun.Frame)}`Frame` keeps a value together with its
heading. For example, a simulation can label its board with a generation number.
Here the value is simply a number:

```lean
open VersoLeanRun Verso.Output

def snapshot (generation : Nat) (value : Nat) : Frame Nat :=
  { label := s!"Generation {generation}"
    content := value }
```

The {lit}`content` field has the type you choose: {lit}`Nat` in this example.
A displayed frame has type {lit}`Frame Html`; its content can include SVG elements.
If you omit the type argument, {lit}`Frame` means {lit}`Frame Html`.

## Errors

Set {lit}`error` to {lit}`some message` to explain a problem in the computation,
such as a calculator instruction that needs more values on the stack. A live
simulation displays the error and disables Play and Step. The reader can start
a fresh run or use Stop to clear the view.

If the input is invalid and there is no state to display, return
{lit}`SequenceView.error` or {lit}`AutomatonView.error`. Problems loading or
running the compiled program are reported separately by verso-run.

## Mapping values

{name (full := VersoLeanRun.Frame.map)}`Frame.map` changes the value while keeping
the label and error message. For example, render the number above as text:

```lean
def displayedSnapshot (generation value : Nat) : Frame :=
  (snapshot generation value).map fun n => Html.ofString s!"Value: {n}"
```

{name (full := Verso.Output.Html.ofString)}`Html.ofString` escapes text, including
reader input. Use Verso's HTML constructors or syntax when you want markup.
Sequences and automata provide {lit}`view` helpers to render all their states.
-/
