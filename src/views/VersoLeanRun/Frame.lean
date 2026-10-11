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

A frame is one labelled HTML observation with an optional domain failure.
Finite sequences and live automata use the same observation type.
-/
public section

namespace VersoLeanRun
open Verso.Output

/-- A labelled observation, shared by finite traces and live models. -/
structure Frame where
  /-- A short domain label, such as a generation or instruction name. -/
  label : String
  /-- The visible observation, displayed in a sandboxed preview. -/
  html : Html
  /-- A domain failure associated with this observation. -/
  error : Option String := none

namespace ViewWire

/-- Typed VIR transport. Markup becomes text only at the sandbox boundary. -/
structure Frame where
  label : String
  html : String
  error : Option String
  deriving Lean.ToJson, Inhabited

end ViewWire

/-- One conversion policy for every rendered observation. -/
def Frame.toWire (frame : Frame) : ViewWire.Frame :=
  { label := frame.label, html := frame.html.asString, error := frame.error }

end VersoLeanRun

/-!
## Using frames

A {name}`VersoLeanRun.Frame` is one visible observation: a label, HTML content,
and an optional domain failure. Finite sequences and live automata use the same
observation type. Return HTML or SVG using {name}`Verso.Output.Html`; reader text
can be escaped with {name}`Verso.Output.Html.text`.

```lean
open VersoLeanRun Verso.Output

def snapshot (generation : Nat) (value : Nat) : Frame :=
  { label := s!"Generation {generation}"
    html := .text true s!"Value: {value}" }
```

An error belongs to the model's meaning, such as an instruction underflow or an
invalid seed. It differs from a host failure to fetch or execute a program.
Use {lit}`SequenceView.error` or {lit}`AutomatonView.error`
when input validation fails before a model state exists.

## Transport

{name}`VersoLeanRun.Frame.toWire` serializes markup at the preview boundary.
{name}`VersoLeanRun.ViewWire.Frame` is the corresponding typed VIR transport.
Author renderers normally work with {name}`VersoLeanRun.Frame` and let the view
adapter perform this conversion.
-/
