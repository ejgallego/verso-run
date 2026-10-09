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
  /-- Actual owning module of the callable, separate from its document placement. -/
  producerModule : String := ""
  /-- String control presentation; this never changes the callable signature. -/
  multiline : Bool := false
  /-- Actual full Lean export name; the declaration remains the author-selected entry. -/
  callable : String := ""
  deriving ToJson, FromJson

end VersoLeanRun
