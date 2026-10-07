/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoManual
public meta import Vir.Attributes
public meta import Vir.Interface.Classify.Signature
public meta import Vir.GeneratePackage.Interface.Encode
public meta import VersoManual.InlineLean
public meta import VersoManual.InlineLean.Scopes

public section
open Lean Verso Doc Elab Genre Manual ArgParse
open Verso.Output.Html
open Verso.Genre.Manual.InlineLean

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

block_extension Block.leanRun (experiment : Experiment) where
  data := toJson experiment
  traverse _ _ _ := pure none
  toTeX := some <| fun _ go _ _ contents => contents.mapM go
  toHtml := some <| fun _ go id data contents => do
    let .ok experiment := fromJson? (α := Experiment) data
      | reportError "Invalid Lean Run experiment description" *> pure .empty
    let source ← contents.mapM go
    let label := if experiment.shape == "nat" then "Natural number" else "Text"
    let initial := experiment.initialInput
    let placeholder := if experiment.shape == "nat" then "0" else "Enter text"
    let sourcePanel := if experiment.collapsed then
      {{ <details class="lean-run-source"><summary> "View Lean implementation" </summary> {{source}} </details> }}
      else {{ <div class="lean-run-source"> {{source}} </div> }}
    let preview := if experiment.output == "html" then
      {{ <iframe class="lean-run-preview" title="HTML result" sandbox="" referrerpolicy="no-referrer" hidden="hidden"/> }}
      else .empty
    pure {{ <section class="lean-run" data-experiment={{data.compress}} data-instance={{toString id}}>
      {{sourcePanel}}
      <div class="lean-run-console">
        <form>
          <label> {{label}} <input type="text" value={{initial}} placeholder={{placeholder}} maxlength="4096" autocomplete="off"/> </label>
          <button type="submit" disabled="disabled"> "Run" </button>
          <button type="button" class="lean-run-stop" disabled="disabled"> "Stop" </button>
        </form>
        <p class="lean-run-status" role="status" aria-live="polite"> "Ready" </p>
        <pre class="lean-run-output" aria-label="Result"/>
        {{preview}}
        <noscript> "Enable JavaScript to run this compiled Lean example." </noscript>
      </div>
    </section> }}
  extraJs := [include_str "../web/bootstrap.js"]
  extraCss := [include_str "../web/lean-run.css"]

structure Config where
  entry : Ident
  input : Option String
  collapsed : Bool
  output : Option String

meta instance : FromArgs Config DocElabM where
  fromArgs := Config.mk <$> .named `entry .ident false <*> .named `input .string true <*>
    .flag `collapsed false <*> .named `output .string true

/-- Adapt the document's typed HTML function at the existing scalar VIR boundary.
The stable suffix is also the declaration selected in the program recipe. -/
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

/-- Elaborate ordinary retained commands, then resolve and classify the selected entry. -/
@[code_block]
meta def leanRun : CodeBlockExpanderOf Config
  | config, str => do
    elabCommands { «show» := true, keep := true, name := none, error := false, fresh := false } str fun shouldShow hls str => do
      let name ← liftM <| Scopes.runWithOpenDecls <| Lean.Elab.realizeGlobalConstNoOverloadWithInfo config.entry
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
        initialInput := config.input.getD (if shape == "nat" then "0" else ""),
        collapsed := config.collapsed,
        output,
        sourceLine := pos.line, sourceColumn := pos.column }
      let source ← toHighlightedLeanBlock shouldShow hls str
      let description ← `(VersoLeanRun.Experiment.mk
        $(quote experiment.program) $(quote experiment.declaration) $(quote experiment.shape)
        $(quote experiment.initialInput)
        $(quote experiment.collapsed)
        $(quote experiment.output)
        $(quote experiment.signature)
        $(quote experiment.sourceLine) $(quote experiment.sourceColumn))
      ``(Verso.Doc.Block.other (VersoLeanRun.Block.leanRun $description) #[$source])
