/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public meta import VersoLeanRun.Model
public import Verso.Doc.Elab
meta import Verso.Instances.Deriving
public import Verso.Output.Html
public import VersoLeanRun.Sequence
public meta import Vir.Attributes
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Lean.ToExpr
public section
open Lean Verso Doc Elab ArgParse
namespace VersoLeanRun

meta section
deriving instance Quote for StringInputMode
deriving instance Quote for InputKind
deriving instance Quote for PresentationKind
deriving instance Quote for FormKind
end

structure Config where
  entry : Ident
  input : Option String
  collapsed : Bool
  multiline : Bool := false

meta instance : FromArgs Config DocElabM where
  fromArgs := Config.mk <$> .named `entry .ident false <*> .named `input .string true <*>
    .flag `collapsed false <*> .flag `multiline false

meta section
/-- Scalar aliases keep their type; rendered results use typed transport adapters. -/
private inductive AdapterKind where
  | scalar | html | sequence
  deriving BEq
end

/-- Registration is selected by the Run entry, after independent type/form checks.
Keep VIR's attribute validator authoritative for executable IR and dependencies. -/
private meta def registerEntry (entry : Ident) (name : Name) : DocElabM Unit := do
  unless (vir_export.getState (← getEnv)).contains name do
    withExporting do
      let .ok attr := getAttributeImpl (← getEnv) `vir_export
        | throwErrorAt entry "Missing VIR export attribute"
      withRef entry <| attr.add name entry .global

/-- Imported callables and rendered views have a document-owned transport adapter.
The producer need not know that a document will select its function. -/
private meta def callableAdapter (entry : Ident) (name : Name) (mode : AdapterKind) : DocElabM Name := do
  let env ← getEnv
  let imported := (env.getModuleIdxFor? name).isSome
  if mode == .scalar && !imported then return name
  let adapter := (if imported then env.mainModule ++ name else name) ++
    (match mode with | .scalar => `leanRun | .html => `leanRunHtml | .sequence => `leanRunSequence)
  let info ← getConstInfo name
  let string := mkConst ``String
  let domain ← if mode == .scalar then pure string else do
    let .forallE _ domain _ .default ← Lean.Meta.whnf info.type
      | throwErrorAt entry "Rendered entries need one explicit scalar input"
    pure domain
  let result := if mode == .sequence then mkConst ``SequenceWire.Payload else string
  let type ← if mode == .scalar then pure info.type else mkArrow domain result
  let value := if mode == .sequence then
    mkLambda `input .default domain <| mkApp (mkConst ``SequenceView.toPayload)
      (mkApp (mkConst name) (.bvar 0))
    else if mode == .html then
    mkLambda `input .default domain <|
      mkApp3 (mkConst ``Verso.Output.Html.asString)
        (mkApp (mkConst name) (.bvar 0)) (mkNatLit 0) (mkConst ``Bool.true)
    else mkConst name
  if let some existing := env.find? adapter then
    unless existing.type == type && existing.value? == some value &&
        (vir_export.getState env).contains adapter do
      throwErrorAt entry "Lean Run adapter name '{adapter}' is already in use"
  else
    withExporting do
      addAndCompile (.defnDecl {
        name := adapter, levelParams := [], type, value,
        hints := .abbrev,
        safety := if info.isUnsafe then .unsafe else .safe }) (logCompileErrors := false)
  return adapter

private meta def unsupportedForm {α : Type} (entry : Ident) (name : Name) (type : Expr)
    (signature : Vir.Interface.ClassifiedSignature) : DocElabM α := do
  let reason : MessageData :=
    if signature.effect != .pure then
      m!"This form cannot run effectful functions (effect: {signature.effect.label}). \
        Move I/O to the document build and export a pure function."
    else if signature.args.size != 1 then
      m!"This form needs one explicit argument; found {signature.args.size}. \
        Export a wrapper taking one String, Nat, Bool, or UInt64 input."
    else
      m!"This form supports homogeneous scalar calls or a scalar input returning Html or SequenceView. \
        Use a supported scalar type or return a typed rendered view."
  throwErrorAt entry "Lean Run entry '{name}' has type {type}.\n\
    This interface is supported by VIR, but not by this Run form.\n\
    {reason}\nUse a pure homogeneous scalar call, or a String, Nat, Bool, or UInt64 input returning Html or SequenceView."

/-- Classify an explicitly resolved callable independently of genre-specific command elaboration.
Selected imported entries and rendered-view adapters are compiled in the document module. -/
meta def describeEntry (config : Config) (name : Name) (str : StrLit) : DocElabM Experiment := do
  if isPrivateName name then
    throwErrorAt config.entry "Lean Run entry '{name}' is private. \
      Export a public wrapper or remove 'private'."
  let info ← getConstInfo name
  if isNoncomputable (← getEnv) name then
    throwErrorAt config.entry "Lean Run entry '{name}' is non-executable.\n\
      Type: {info.type}\nUse an executable public definition instead of a noncomputable value."
  let entryType ← Lean.Meta.whnf info.type
  let isHtml := match entryType with
    | .forallE _ _ result .default =>
      info.levelParams.isEmpty &&
        result.isConstOf ``Verso.Output.Html
    | _ => false
  let isSequence := match entryType with
    | .forallE _ _ result .default =>
      info.levelParams.isEmpty && result.isConstOf ``SequenceView
    | _ => false
  let mode : AdapterKind := if isHtml then .html else if isSequence then .sequence else .scalar
  -- Classify the source interface independently before registering scalar exports.
  -- Html uses markup; SequenceView uses a typed payload with a compiler-derived ABI.
  let sourceName := name
  let name ← if mode == .scalar then pure name else callableAdapter config.entry name mode
  let info ← getConstInfo name
  let callSignature ← match ← Vir.Interface.analyzeExportInterface info.type with
    | .ok sig => pure sig
    | .error error => throwErrorAt config.entry
        "Lean Run entry '{name}' has an unsupported VIR interface.\n\
          Type: {info.type}\nVIR: {error.toMessageData}"
  let form : FormKind ← match callSignature.args, callSignature.effect with
    | #[argument], .pure => do
      let input ← match argument.type with
        | .string => pure (InputKind.string (if config.multiline then .multiline else .line))
        | .nat => pure .nat
        | .bool => pure .bool
        | .uint64 => pure .uint64
        | _ => unsupportedForm config.entry sourceName entryType callSignature
      let admitted := match mode, callSignature.result with
        | .sequence, .structure result .. => result == ``SequenceWire.Payload
        | .html, .string => true
        | .scalar, result => result == argument.type
        | _, _ => false
      unless admitted do
        unsupportedForm (α := Unit) config.entry sourceName entryType callSignature
      pure { input, presentation := match mode with | .scalar => .text | .html => .html | .sequence => .sequence }
    | _, _ => unsupportedForm config.entry sourceName entryType callSignature
  if config.multiline && form.scalar != .string then
    throwErrorAt config.entry "Lean Run multiline input requires a String argument"
  if form.scalar == .bool then
    if let some input := config.input then
      unless input == "true" || input == "false" do
        throwErrorAt config.entry "Lean Run Boolean preset must be 'true' or 'false'"
  let name ← if mode == .scalar then callableAdapter config.entry name .scalar else pure name
  registerEntry config.entry name
  let env ← getEnv
  let pos := (← getFileMap).toPosition <| str.raw.getPos?.getD 0
  let experiment : Experiment := {
    program := env.mainModule.toString, declaration := sourceName.toString, callable := name.toString, form,
    producerModule := match env.getModuleIdxFor? name with
      | some idx => env.header.moduleNames[idx.toNat]!.toString
      | none => env.mainModule.toString,
    initialInput := config.input.getD (if form.scalar == .nat || form.scalar == .uint64 then "0"
      else if form.scalar == .bool then "false" else ""),
    collapsed := config.collapsed,
    sourceLine := pos.line, sourceColumn := pos.column }
  return experiment

/-- Quote validated metadata for native genre constructors. -/
meta def quoteExperiment (experiment : Experiment) : DocElabM Term := do
  return ← `(VersoLeanRun.Experiment.mk
    $(quote experiment.program) $(quote experiment.declaration) $(quote experiment.form)
    $(quote experiment.initialInput)
    $(quote experiment.collapsed)
    $(quote experiment.sourceLine) $(quote experiment.sourceColumn)
    $(quote experiment.producerModule) $(quote experiment.callable))

end VersoLeanRun
