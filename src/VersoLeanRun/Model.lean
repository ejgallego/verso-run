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

inductive ScalarKind where
  | string | nat | bool | uint64
  deriving BEq, Repr

/-- Forms admitted by the callable classifier. Presentation is part of the form,
so multiline and HTML controls can only carry String inputs and results. -/
inductive FormKind where
  | string | multilineString | nat | bool | uint64 | html | multilineHtml
  deriving BEq, Repr, ToJson

/-- The wire representation is a closed string tag, not an extensible record.
Reject object encodings that could silently discard unsupported options. -/
instance : FromJson FormKind where
  fromJson? json := do
    match ← json.getStr? with
    | "string" => pure .string
    | "multilineString" => pure .multilineString
    | "nat" => pure .nat
    | "bool" => pure .bool
    | "uint64" => pure .uint64
    | "html" => pure .html
    | "multilineHtml" => pure .multilineHtml
    | tag => throw s!"Unsupported Lean Run form '{tag}'"

def FormKind.scalar : FormKind → ScalarKind
  | .nat => .nat
  | .bool => .bool
  | .uint64 => .uint64
  | .string | .multilineString | .html | .multilineHtml => .string

def FormKind.multiline : FormKind → Bool
  | .multilineString | .multilineHtml => true
  | _ => false

def FormKind.isHtml : FormKind → Bool
  | .html | .multilineHtml => true
  | _ => false

/-- Portable call description admitted from the independently classified Lean
interface. Runtime URLs and encoded expected signatures belong to publication. -/
structure Experiment where
  program : String
  declaration : String
  form : FormKind
  initialInput : String
  collapsed : Bool
  sourceLine : Nat
  sourceColumn : Nat
  /-- Actual owning module of the callable, separate from its document placement. -/
  producerModule : String
  /-- Actual full Lean export name; the declaration remains the author-selected entry. -/
  callable : String
  deriving ToJson, FromJson

end VersoLeanRun
