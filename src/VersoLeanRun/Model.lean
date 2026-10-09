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

inductive StringInputMode where
  | line | multiline
  deriving BEq, Repr

/-- String transport and result presentation are separate. A new String view does
not change the callable ABI or permit rendered views on numeric/Boolean forms. -/
inductive StringPresentation where
  | text | html | sequence
  deriving BEq, Repr

inductive FormKind where
  | string (input : StringInputMode) (presentation : StringPresentation)
  | nat | bool | uint64
  deriving BEq, Repr

instance : ToJson FormKind where
  toJson form := .str <| match form with
    | .string .line .text => "string"
    | .string .multiline .text => "multilineString"
    | .string .line .html => "html"
    | .string .multiline .html => "multilineHtml"
    | .string .line .sequence => "sequence"
    | .string .multiline .sequence => "multilineSequence"
    | .nat => "nat"
    | .bool => "bool"
    | .uint64 => "uint64"

/-- Accept exactly the supported string tags. Object encodings must not silently
lose unsupported options at the native metadata boundary. -/
instance : FromJson FormKind where
  fromJson? json := do
    match ← json.getStr? with
    | "string" => pure (.string .line .text)
    | "multilineString" => pure (.string .multiline .text)
    | "nat" => pure .nat
    | "bool" => pure .bool
    | "uint64" => pure .uint64
    | "html" => pure (.string .line .html)
    | "multilineHtml" => pure (.string .multiline .html)
    | "sequence" => pure (.string .line .sequence)
    | "multilineSequence" => pure (.string .multiline .sequence)
    | tag => throw s!"Unsupported Lean Run form '{tag}'"

def FormKind.scalar : FormKind → ScalarKind
  | .nat => .nat
  | .bool => .bool
  | .uint64 => .uint64
  | .string .. => .string

def FormKind.multiline : FormKind → Bool
  | .string .multiline _ => true
  | _ => false

def FormKind.isHtml : FormKind → Bool
  | .string _ .html => true
  | _ => false

def FormKind.isSequence : FormKind → Bool
  | .string _ .sequence => true
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
