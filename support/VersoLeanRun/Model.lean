/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Data.Json.FromToJson
public section
open Lean

namespace VersoLeanRun

/-- Portable build-validated call description. Runtime URLs belong to publication. -/
structure Experiment where
  program : String
  declaration : String
  shape : String
  initialInput : String
  collapsed : Bool
  output : String
  /-- VIR's canonical callable signature, serialized during document elaboration. -/
  signature : String
  sourceLine : Nat
  sourceColumn : Nat
  deriving ToJson, FromJson

end VersoLeanRun
