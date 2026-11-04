/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Vir.Resources
public import Lean.Data.Json.Parser
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term
public section
namespace VersoLeanRun

/-- A concrete result type and its independently compiled call contracts.
Construct with `resultType% My.Result` in the native publisher.
-/
structure ResultType where
  name : String
  stringSignature : String
  natSignature : String
  boolSignature : String
  uint64Signature : String

def ResultType.expectedExport (type : ResultType) (input : ScalarKind) : Except String Lean.Json :=
  Lean.Json.parse <| match input with
    | .string => type.stringSignature
    | .nat => type.natSignature
    | .bool => type.boolSignature
    | .uint64 => type.uint64Signature

open Lean Elab Term in
/-- Classify scalar calls returning the given concrete type, without inspecting
the downloaded program. The ordinary model module can stay free of compiler imports.
-/
elab "resultType%" type:ident : term => do
  let name ← resolveGlobalConstNoOverload type
  let result ← Meta.whnf (mkConst name)
  let .const name [] := result
    | throwErrorAt type "A result presenter needs a concrete, unparameterized result type"
  let classify (input : Name) : TermElabM String := do
    let signature ← match ← Vir.Interface.analyzeExportInterface
        (mkForall `input .default (mkConst input) result) with
      | .ok signature => pure signature
      | .error error => throwErrorAt type "Cannot classify result presenter: {error.toMessageData}"
    unless signature.effect == .pure do
      throwErrorAt type "A result presenter needs a pure result interface"
    match signature.result with
    | .structure .. | .customInductive .. => pure signature.toExpectedSignatureJson
    | _ => throwErrorAt type "A result presenter needs a concrete structure or inductive result"
  let string ← classify ``String
  let nat ← classify ``Nat
  let bool ← classify ``Bool
  let uint64 ← classify ``UInt64
  elabTerm (← `(ResultType.mk $(quote name.toString) $(quote string) $(quote nat)
    $(quote bool) $(quote uint64))) none

/-- Publish a worker normalizer and a result-only renderer for one concrete Lean
result type. Module and auxiliary paths are site-relative, beneath `lean-run/`.
The stock host retains controls, execution, cancellation and placement ownership.
-/
structure ResultPresenter where
  resultType : ResultType
  workerModule : Vir.Resources.File
  rendererModule : Vir.Resources.File
  files : Array Vir.Resources.File := #[]

private def safePath (path : String) : Bool :=
  path.startsWith "lean-run/" && (path.splitOn "/").all (fun part =>
    !part.isEmpty && part != "." && part != ".." &&
      part.toList.all (fun c => c.isAlphanum && c.toNat < 128 || c == '-' || c == '_' || c == '.'))

/-- Validate custom files against the complete reserved inventory before writes.
Also reject case aliases and file/directory collisions on portable static hosts.
-/
def ResultPresenter.inventory (presenters : Array ResultPresenter)
    (existing : Array Vir.Resources.File) : Except String (Array Vir.Resources.File × Lean.Json) := do
  let mut files := existing
  let mut registry := #[]
  let mut names : Array String := #[]
  for presenter in presenters do
    let name := presenter.resultType.name
    if name.isEmpty || ["text", "html", "sequence", "automaton"].contains name then
      throw s!"Invalid or reserved result presenter type '{name}'"
    if names.contains name then throw s!"Duplicate result presenter for type '{name}'"
    names := names.push name
    for file in #[presenter.workerModule, presenter.rendererModule] ++ presenter.files do
      unless safePath file.path do throw s!"Unsafe result presenter path '{file.path}'"
      let path := file.path.toLower
      if files.any (fun prior => prior.path.toLower == path ||
          prior.path.toLower.startsWith (path ++ "/") || path.startsWith (prior.path.toLower ++ "/")) then
        throw s!"Colliding result presenter path '{file.path}'"
      files := files.push file
    registry := registry.push (name, Lean.Json.mkObj [
      ("workerModule", .str presenter.workerModule.path),
      ("rendererModule", .str presenter.rendererModule.path)])
  return (files, Lean.Json.mkObj registry.toList)

end VersoLeanRun
