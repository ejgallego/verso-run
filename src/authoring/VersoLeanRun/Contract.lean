/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoLeanRun.Model
public import VersoLeanRun.Views
public import Lean.Data.Json.Parser
public import Vir.Compiler.Interface.Encode
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term

public section
namespace VersoLeanRun

open Lean Elab Term in
elab "renderedCallableExpected%" input:ident result:ident : term => do
  let input ← resolveGlobalConstNoOverload input
  let result ← resolveGlobalConstNoOverload result
  let type := mkForall `input .default (mkConst input) (mkConst result)
  let signature ← match ← Vir.Interface.analyzeExportInterface type with
    | .ok signature => pure signature
    | .error error => throwError "Cannot classify the rendered callable: {error.toMessageData}"
  return mkStrLit signature.toExpectedSignatureJson

/-- Encode the admitted input/result pair through VIR, independently of the
program bundle. Structured results use the compiled payload layout. -/
def FormKind.expectedExport (form : FormKind) : Except String Lean.Json := do
  if form.customResult?.isSome then
    throw "A custom result needs its registered compiler contract"
  if form.presentation != .text then
    return ← Lean.Json.parse <| match form.scalar, form.presentation with
      | .string, .html => (renderedCallableExpected% String Lean.Html)
      | .nat, .html => (renderedCallableExpected% Nat Lean.Html)
      | .bool, .html => (renderedCallableExpected% Bool Lean.Html)
      | .uint64, .html => (renderedCallableExpected% UInt64 Lean.Html)
      | .string, .sequence => (renderedCallableExpected% String SequenceView)
      | .nat, .sequence => (renderedCallableExpected% Nat SequenceView)
      | .bool, .sequence => (renderedCallableExpected% Bool SequenceView)
      | .uint64, .sequence => (renderedCallableExpected% UInt64 SequenceView)
      | .string, .automaton => (renderedCallableExpected% String AutomatonView)
      | .nat, .automaton => (renderedCallableExpected% Nat AutomatonView)
      | .bool, .automaton => (renderedCallableExpected% Bool AutomatonView)
      | .uint64, .automaton => (renderedCallableExpected% UInt64 AutomatonView)
      | _, .text => unreachable!
      | _, .custom _ => unreachable!
  let type : Vir.Interface.InterfaceType := match form.scalar with
    | .string => .string
    | .nat => .nat
    | .bool => .bool
    | .uint64 => .uint64
  let signature : Vir.Interface.ClassifiedSignature := {
    args := #[{ name := "input", type }], result := type, effect := .pure }
  Lean.Json.parse signature.toExpectedSignatureJson

end VersoLeanRun
