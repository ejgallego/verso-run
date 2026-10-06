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
    let initial := if experiment.shape == "nat" then "0" else ""
    let placeholder := if experiment.shape == "nat" then "0" else "Enter text"
    pure {{ <section class="lean-run" data-experiment={{data.compress}} data-instance={{toString id}}>
      <div class="lean-run-source"> {{source}} </div>
      <div class="lean-run-console">
        <form>
          <label> {{label}} <input type="text" value={{initial}} placeholder={{placeholder}} maxlength="4096" autocomplete="off"/> </label>
          <button type="submit" disabled="disabled"> "Run" </button>
          <button type="button" class="lean-run-stop" disabled="disabled"> "Stop" </button>
        </form>
        <p class="lean-run-status" role="status" aria-live="polite"> "Ready" </p>
        <pre class="lean-run-output" aria-label="Result"/>
        <noscript> "Enable JavaScript to run this compiled Lean example." </noscript>
      </div>
    </section> }}
  extraJs := [include_str "../web/bootstrap.js"]
  extraCss := [include_str "../web/lean-run.css"]

structure Config where
  entry : Ident

meta instance : FromArgs Config DocElabM where
  fromArgs := Config.mk <$> .named `entry .ident false

/-- Elaborate ordinary retained commands, then resolve and classify the selected entry. -/
@[code_block]
meta def leanRun : CodeBlockExpanderOf Config
  | config, str => do
    elabCommands { «show» := true, keep := true, name := none, error := false, fresh := false } str fun shouldShow hls str => do
      let name ← liftM <| Scopes.runWithOpenDecls <| Lean.Elab.realizeGlobalConstNoOverloadWithInfo config.entry
      let env ← getEnv
      unless (vir_export.getState env).contains name do
        throwErrorAt config.entry "Lean Run entry '{name}' must carry @[vir_export]"
      let info ← getConstInfo name
      let .ok callSignature ← Vir.Interface.analyzeExportInterface info.type
        | throwErrorAt config.entry "Lean Run entry '{name}' has an unsupported VIR interface"
      let shape ← match callSignature.args, callSignature.result, callSignature.effect with
        | #[{ type := .string, .. }], .string, .pure => pure "string"
        | #[{ type := .nat, .. }], .nat, .pure => pure "nat"
        | _, _, _ => throwErrorAt config.entry "Lean Run supports exactly String → String and Nat → Nat (one explicit argument, pure and monomorphic); entry '{name}' does not match"
      let pos := (← getFileMap).toPosition <| str.raw.getPos?.getD 0
      let signature := Vir.GeneratePackage.jsonObject #[
        ("args", Vir.GeneratePackage.jsonArray (callSignature.args.map (·.type.toJson))),
        ("result", callSignature.result.toJson),
        ("effect", Vir.GeneratePackage.jsonString callSignature.effect.label)]
      let experiment : Experiment := {
        program := env.mainModule.toString, declaration := name.toString, shape, signature,
        sourceLine := pos.line, sourceColumn := pos.column }
      let source ← toHighlightedLeanBlock shouldShow hls str
      let description ← `(VersoLeanRun.Experiment.mk
        $(quote experiment.program) $(quote experiment.declaration) $(quote experiment.shape)
        $(quote experiment.signature)
        $(quote experiment.sourceLine) $(quote experiment.sourceColumn))
      ``(Verso.Doc.Block.other (VersoLeanRun.Block.leanRun $description) #[$source])
