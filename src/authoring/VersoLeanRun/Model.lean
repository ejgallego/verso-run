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

inductive InputKind where
  | string (mode : StringInputMode)
  | nat | bool | uint64
  deriving BEq, Repr

/-- Presentation is independent of the concrete input control. Plain text retains
the input's scalar type; rendered results use their own transport contract. -/
inductive PresentationKind where
  | text | html | sequence | automaton
  | custom (resultType : String)
  deriving BEq, Repr

structure FormKind where
  input : InputKind
  presentation : PresentationKind := .text
  deriving BEq, Repr

instance : ToJson FormKind where
  toJson form := Id.run do
    if let .custom resultType := form.presentation then
      let input := match form.input with
        | .string .line => "string"
        | .string .multiline => "multilineString"
        | .nat => "nat"
        | .bool => "bool"
        | .uint64 => "uint64"
      return .mkObj [("input", .str input), ("presenter", .str resultType)]
    return .str <| match form with
    | ⟨.string .line, .text⟩ => "string"
    | ⟨.string .multiline, .text⟩ => "multilineString"
    | ⟨.string .line, .html⟩ => "html"
    | ⟨.string .multiline, .html⟩ => "multilineHtml"
    | ⟨.string .line, .sequence⟩ => "sequence"
    | ⟨.string .multiline, .sequence⟩ => "multilineSequence"
    | ⟨.nat, .text⟩ => "nat"
    | ⟨.bool, .text⟩ => "bool"
    | ⟨.uint64, .text⟩ => "uint64"
    | ⟨.nat, .html⟩ => "natHtml"
    | ⟨.bool, .html⟩ => "boolHtml"
    | ⟨.uint64, .html⟩ => "uint64Html"
    | ⟨.nat, .sequence⟩ => "natSequence"
    | ⟨.bool, .sequence⟩ => "boolSequence"
    | ⟨.uint64, .sequence⟩ => "uint64Sequence"
    | ⟨.string .line, .automaton⟩ => "automaton"
    | ⟨.string .multiline, .automaton⟩ => "multilineAutomaton"
    | ⟨.nat, .automaton⟩ => "natAutomaton"
    | ⟨.bool, .automaton⟩ => "boolAutomaton"
    | ⟨.uint64, .automaton⟩ => "uint64Automaton"
    | ⟨_, .custom _⟩ => unreachable!

/-- Accept the built-in string tags and the exact custom-result object shape.
Reject unknown options at the native metadata boundary. -/
instance : FromJson FormKind where
  fromJson? json := do
    if let .obj fields := json then
      unless fields.size == 2 do throw "Invalid custom Lean Run form"
      let presenter ← json.getObjValAs? String "presenter"
      if presenter.isEmpty then throw "Empty Lean Run presenter type"
      let input ← match ← json.getObjValAs? String "input" with
        | "string" => pure (.string .line)
        | "multilineString" => pure (.string .multiline)
        | "nat" => pure .nat
        | "bool" => pure .bool
        | "uint64" => pure .uint64
        | _ => throw "Unsupported custom Lean Run input"
      return ⟨input, .custom presenter⟩
    match ← json.getStr? with
    | "string" => pure ⟨.string .line, .text⟩
    | "multilineString" => pure ⟨.string .multiline, .text⟩
    | "nat" => pure ⟨.nat, .text⟩
    | "bool" => pure ⟨.bool, .text⟩
    | "uint64" => pure ⟨.uint64, .text⟩
    | "html" => pure ⟨.string .line, .html⟩
    | "multilineHtml" => pure ⟨.string .multiline, .html⟩
    | "sequence" => pure ⟨.string .line, .sequence⟩
    | "multilineSequence" => pure ⟨.string .multiline, .sequence⟩
    | "natHtml" => pure ⟨.nat, .html⟩
    | "boolHtml" => pure ⟨.bool, .html⟩
    | "uint64Html" => pure ⟨.uint64, .html⟩
    | "natSequence" => pure ⟨.nat, .sequence⟩
    | "boolSequence" => pure ⟨.bool, .sequence⟩
    | "uint64Sequence" => pure ⟨.uint64, .sequence⟩
    | "automaton" => pure ⟨.string .line, .automaton⟩
    | "multilineAutomaton" => pure ⟨.string .multiline, .automaton⟩
    | "natAutomaton" => pure ⟨.nat, .automaton⟩
    | "boolAutomaton" => pure ⟨.bool, .automaton⟩
    | "uint64Automaton" => pure ⟨.uint64, .automaton⟩
    | tag => throw s!"Unsupported Lean Run form '{tag}'"

def InputKind.scalar : InputKind → ScalarKind
  | .nat => .nat
  | .bool => .bool
  | .uint64 => .uint64
  | .string _ => .string

def FormKind.scalar (form : FormKind) : ScalarKind := form.input.scalar

def FormKind.multiline (form : FormKind) : Bool :=
  form.input == .string .multiline

def FormKind.isHtml (form : FormKind) : Bool := form.presentation == .html

def FormKind.isSequence (form : FormKind) : Bool := form.presentation == .sequence

def FormKind.isAutomaton (form : FormKind) : Bool := form.presentation == .automaton

def FormKind.customResult? (form : FormKind) : Option String :=
  match form.presentation with
  | .custom name => some name
  | _ => none

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
