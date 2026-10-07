/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public meta import VersoLeanRun.Model
public import Verso.Doc.Elab
public import Verso.Output.Html
public meta import Vir.Attributes
public meta import Vir.Interface.Classify.Signature
public meta import Vir.GeneratePackage.Interface.Encode
public meta import Lean.ToExpr
public section
open Lean Verso Doc Elab ArgParse
namespace VersoLeanRun

structure Config where
  entry : Ident
  input : Option String
  collapsed : Bool
  output : Option String

meta instance : FromArgs Config DocElabM where
  fromArgs := Config.mk <$> .named `entry .ident false <*> .named `input .string true <*>
    .flag `collapsed false <*> .named `output .string true

/-- Adapt the document's typed HTML function at the existing scalar VIR boundary.
The stable suffix is the full declaration selected in the generated root interface. -/
private meta def htmlAdapter (entry : Ident) (name : Name) : DocElabM Name := withRef entry do
  if isNoncomputable (← getEnv) name then
    throwErrorAt entry "Lean Run HTML entry '{name}' is non-executable"
  let adapter := name ++ `leanRunHtml
  let string := mkConst ``String
  let type ← mkArrow string string
  let value := mkLambda `input .default string <|
    mkApp3 (mkConst ``Verso.Output.Html.asString)
      (mkApp (mkConst name) (.bvar 0)) (mkNatLit 0) (mkConst ``Bool.true)
  if let some existing := (← getEnv).find? adapter then
    unless existing.type == type && existing.value? == some value &&
        (vir_export.getState (← getEnv)).contains adapter do
      throwErrorAt entry "Lean Run HTML adapter name '{adapter}' is already in use"
  else
    withExporting do
      addAndCompile (.defnDecl {
        name := adapter
        levelParams := []
        type := type
        value := value
        hints := .abbrev
        safety := .safe }) (logCompileErrors := false)
      let .ok attr := getAttributeImpl (← getEnv) `vir_export
        | throwError "Missing VIR export attribute"
      attr.add adapter (← `(attr| vir_export)) .global
  return adapter

private meta def unsupportedForm (entry : Ident) (name : Name) (type : Expr)
    (signature : Vir.Interface.ClassifiedSignature) : DocElabM String := do
  let reason : MessageData :=
    if signature.effect != .pure then
      m!"This form cannot run effectful functions (effect: {signature.effect.label}). \
        Move I/O to the document build and export a pure function."
    else if signature.args.size != 1 then
      m!"This form needs one explicit argument; found {signature.args.size}. \
        Export a wrapper taking one String or Nat input."
    else
      m!"This form supports exactly String → String and Nat → Nat. \
        Serialize structured inputs and results as text, or return typed HTML."
  throwErrorAt entry "Lean Run entry '{name}' has type {type}.\n\
    This interface is supported by VIR, but not by this Run form.\n\
    {reason}\nUse a pure String → String, Nat → Nat, or String → Html function."

/-- Classify an explicitly resolved callable independently of genre-specific command elaboration.
HTML adapters are compiled in the current document module, so external sources opt out. -/
meta def describeEntry (config : Config) (name : Name) (str : StrLit)
    (allowHtml : Bool := true) : DocElabM Experiment := do
  if isPrivateName name then
    throwErrorAt config.entry "Lean Run entry '{name}' is private. \
      Export a public wrapper or remove 'private'."
  let info ← getConstInfo name
  if isNoncomputable (← getEnv) name then
    throwErrorAt config.entry "Lean Run entry '{name}' is non-executable.\n\
      Type: {info.type}\nUse an executable public definition instead of a noncomputable value."
  let entryType ← Lean.Meta.whnf info.type
  let isHtml := match entryType with
    | .forallE _ domain result .default =>
      info.levelParams.isEmpty && domain.isConstOf ``String &&
        result.isConstOf ``Verso.Output.Html
    | _ => false
  if isHtml && !allowHtml then
    throwErrorAt config.entry "Lean Run anchored HTML entries need a scalar adapter owned by the producer. \
      Export a String → String serialization wrapper in the selected anchor."
  let output := config.output.getD (if isHtml then "html" else "text")
  unless output == "text" || output == "html" do
    throwErrorAt config.entry "Lean Run output must be 'text' or 'html'"
  if isHtml && output != "html" then
    throwErrorAt config.entry "Lean Run String → Html entries require HTML output"
  let name ← if isHtml then htmlAdapter config.entry name else pure name
  let env ← getEnv
  let info ← getConstInfo name
  let callSignature ← match ← Vir.Interface.analyzeExportInterface info.type with
    | .ok sig => pure sig
    | .error error => throwErrorAt config.entry
        "Lean Run entry '{name}' has an unsupported VIR interface.\n\
          Type: {info.type}\nVIR: {error.toMessageData}"
  let shape ← match callSignature.args, callSignature.result, callSignature.effect with
    | #[{ type := .string, .. }], .string, .pure => pure "string"
    | #[{ type := .nat, .. }], .nat, .pure => pure "nat"
    | _, _, _ => unsupportedForm config.entry name info.type callSignature
  unless (vir_export.getState env).contains name do
    throwErrorAt config.entry "Lean Run entry '{name}' must carry @[vir_export].\n\
      Type: {info.type}\nAdd the attribute to its public definition. If it is already \
      present, fix the earlier VIR compilation or dependency error first."
  if output == "html" && shape != "string" then
    throwErrorAt config.entry "Lean Run HTML output requires a String result"
  let pos := (← getFileMap).toPosition <| str.raw.getPos?.getD 0
  let signature := Vir.GeneratePackage.jsonObject #[
    ("args", Vir.GeneratePackage.jsonArray (callSignature.args.map (·.type.toJson))),
    ("result", callSignature.result.toJson),
    ("effect", Vir.GeneratePackage.jsonString callSignature.effect.label)]
  let experiment : Experiment := {
    program := env.mainModule.toString, declaration := name.toString, shape, signature,
    producerModule := match env.getModuleIdxFor? name with
      | some idx => env.header.moduleNames[idx.toNat]!.toString
      | none => env.mainModule.toString,
    initialInput := config.input.getD (if shape == "nat" then "0" else ""),
    collapsed := config.collapsed,
    output,
    sourceLine := pos.line, sourceColumn := pos.column }
  return experiment

/-- Preserve the existing serialized experiment and constructor shape. -/
meta def quoteExperiment (experiment : Experiment) : DocElabM Term := do
  return ← `(VersoLeanRun.Experiment.mk
    $(quote experiment.program) $(quote experiment.declaration) $(quote experiment.shape)
    $(quote experiment.initialInput)
    $(quote experiment.collapsed)
    $(quote experiment.output)
    $(quote experiment.signature)
    $(quote experiment.sourceLine) $(quote experiment.sourceColumn)
    $(quote experiment.producerModule))

end VersoLeanRun
