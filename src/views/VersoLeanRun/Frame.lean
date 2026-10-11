/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Verso.Output.Html
public import Lean.Data.Json.FromToJson
public section

namespace VersoLeanRun
open Verso.Output

/-- A labelled observation, shared by finite traces and live models. -/
structure Frame where
  label : String
  html : Html
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
