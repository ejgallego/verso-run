/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public meta import VersoCast.Manual.Preview.Server
public meta import VersoLeanRun.Collect
public meta import VersoLeanRun.Contract
public meta import Vir.Infoview.Package
public meta import Vir.Attributes

public meta section
namespace VersoLeanRun.Cast.Server
open Lean Server Lean.Vir.Infoview VersoCast.Manual.Preview.Server

structure ProgramParams where
  snapshotRef : WithRpcRef Page
  document : String
  declaration : String
  deriving RpcEncodable

structure ProgramReply where
  uri : Lsp.DocumentUri
  version : Nat
  callable : String
  fingerprint : String
  expectedExport : Json
  packageBase64 : String
  deriving RpcEncodable

private def decodeRun (block : Verso.Genre.Manual.Block) : Except String (Option Experiment) := do
  if block.name == `VersoLeanRun.Block.leanRun then
    return some (← fromJson? block.data)
  return none

/-- Resolve an admitted Run entry in the exact captured page. The browser never
selects an arbitrary compiler root or supplies the expected signature. -/
@[server_rpc_method]
def program (params : ProgramParams) : RequestM (RequestTask ProgramReply) :=
  RequestM.asTask do
    let page := params.snapshotRef.val
    requireErrorFree page
    let entries ← match experiments decodeRun page.document with
      | .ok entries => pure entries
      | .error error => throw ⟨.invalidParams, error⟩
    let some entry := entries.find? (fun entry =>
        entry.program == params.document && entry.declaration == params.declaration)
      | throw ⟨.invalidParams, "The selected page has no such Run entry"⟩
    let expected ← match entry.form.expectedExport with
      | .ok expected => pure expected
      | .error error => throw ⟨.invalidParams, error⟩
    let root ← match Vir.parseDottedName entry.callable with
      | .ok root => pure root
      | .error error => throw ⟨.invalidParams, error⟩
    unless (vir_export.getState page.env).contains root do
      throw ⟨.invalidParams, "The selected callable is not registered for Run execution"⟩
    let some declaration := page.env.find? root
      | throw ⟨.invalidParams, "The selected callable is unavailable"⟩
    let signature ← (withOptions (fun _ => page.options)
      (Vir.Interface.analyzeExportInterface declaration.type)).toIO'
      { fileName := page.meta.uri, fileMap := .ofString "" }
      { env := page.env }
    let actual ← match signature with
      | .ok signature => match Lean.Json.parse signature.toExpectedSignatureJson with
        | .ok signature => pure signature
        | .error error => throw ⟨.internalError, error⟩
      | .error error =>
        let reason ← error.toMessageData.toString
        throw ⟨.invalidParams, s!"Cannot prepare {entry.callable}: {reason}"⟩
    unless actual == expected do
      throw ⟨.invalidParams, "The selected callable no longer has the admitted Run signature"⟩
    let (fingerprint, package) ← match ← prepareWidgetPackage page.meta.uri page.env root with
      | .ok package => pure package
      | .error error => throw ⟨.invalidParams, error⟩
    let bytes ← match Vir.GeneratePackage.emitPackage package.closure package.manifest with
      | .ok bytes => pure bytes
      | .error error => throw ⟨.invalidParams, error⟩
    let encoded := base64Encode bytes
    requireMatchingVersion page
    pure {
      uri := page.meta.uri
      version := page.meta.version
      callable := entry.callable
      fingerprint := fingerprint
      expectedExport := expected
      packageBase64 := encoded }

end VersoLeanRun.Cast.Server
