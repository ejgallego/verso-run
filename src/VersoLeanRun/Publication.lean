/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Lean.Data.Json.Parser
public import Std.Data.TreeMap.Basic
public import Vir.Resources
public import Vir.Compiler.Interface.Encode
public import VersoLeanRun.Sequence
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term
public import VersoLeanRunPresenterResources
public section
open Vir.Resources
namespace VersoLeanRun

open Lean Elab Term in
elab "sequenceCallableExpected%" input:ident : term => do
  let type := mkForall `input .default (mkConst input.getId) (mkConst ``SequenceWire.Payload)
  let .ok signature ← Vir.Interface.analyzeExportInterface type
    | throwError "Cannot classify the typed sequence transport"
  return mkStrLit signature.toExpectedSignatureJson

/-- Complete validated inventory, ready for a genre's output or asset planner. -/
structure Publication where
  files : Array File
  plan : Lean.Json

/-- Exact repeated runtime values need no separate hashing: publication validates
that retained value. A different representation is validated before being discarded.
Program payload validation belongs exclusively to VIR's forSite publication boundary. -/
def combineResources (resources additional : ResourceSet) : Except String ResourceSet := do
  let sameRuntime := resources.runtime.contentId == additional.runtime.contentId &&
    resources.runtime.descriptor == additional.runtime.descriptor &&
    (resources.runtime.files.qsort (·.path < ·.path)).map (fun f => (f.path, f.bytes)) ==
      (additional.runtime.files.qsort (·.path < ·.path)).map (fun f => (f.path, f.bytes))
  unless sameRuntime do
    additional.runtime.validate.mapError reprStr
  unless resources.runtime.contentId == additional.runtime.contentId do
    throw s!"RUNTIME_CONTENT_ID_CONFLICT: cannot combine resource sets with runtimes {resources.runtime.contentId} and {additional.runtime.contentId}"
  return { resources with programs := resources.programs ++ additional.programs }

/-- Encode the admitted input/result pair through VIR, independently of the
program bundle. Structured results use the compiled payload layout. -/
def FormKind.expectedExport (form : FormKind) : Except String Lean.Json := do
  if form.isSequence then
    return ← Lean.Json.parse <| match form.scalar with
      | .string => (sequenceCallableExpected% String)
      | .nat => (sequenceCallableExpected% Nat)
      | .bool => (sequenceCallableExpected% Bool)
      | .uint64 => (sequenceCallableExpected% UInt64)
  let type : Vir.Interface.InterfaceType := match form.scalar with
    | .string => .string
    | .nat => .nat
    | .bool => .bool
    | .uint64 => .uint64
  let signature : Vir.Interface.ClassifiedSignature := {
    args := #[{ name := "input", type }], result := if form.isHtml then .string else type, effect := .pure }
  Lean.Json.parse signature.toExpectedSignatureJson

private structure RegisteredBinding where
  source : Experiment
  value : Lean.Json

private abbrev PublicationBindings :=
  Std.TreeMap String (Std.TreeMap String RegisteredBinding)

/-- One binding per document/entry, retaining the first registration for diagnostics.
Placement options remain on each form and do not participate in this identity. -/
private def registerBinding (bindings : PublicationBindings) (experiment : Experiment)
    (binding : Lean.Json) : Except String PublicationBindings := do
  let declarations := (bindings[experiment.program]?).getD {}
  if let some previous := declarations[experiment.declaration]? then
    let first := previous.source
    unless previous.value == binding && first.callable == experiment.callable do
      throw <| s!"{experiment.program}:{experiment.sourceLine}:{experiment.sourceColumn}: PUBLICATION_BINDING_CONFLICT: conflicting registration for {experiment.declaration} in document {experiment.program}. " ++
        s!"First at {first.program}:{first.sourceLine}:{first.sourceColumn} (producer {first.producerModule}, callable {first.callable}, binding {previous.value.compress}); " ++
        s!"incoming producer {experiment.producerModule}, callable {experiment.callable}, binding {binding.compress}. " ++
        "Repeated placements must use the same callable, manifest, and expected signature."
    return bindings
  return bindings.insert experiment.program <|
    declarations.insert experiment.declaration { source := experiment, value := binding }

/-- Plan the supplied inventory without acquiring or replacing its runtime.
Resolve declarations and validate contracts before performing any output writes. -/
def preparePublication (rendered : Array Experiment) (resources : ResourceSet)
    (resourcePrefix : String := "lean-run/resources") : Except String Publication := do
  let sequence := rendered.any (·.form.isSequence)
  let html := rendered.any (·.form.isHtml)
  let resources ← if sequence || html then
    combineResources resources VersoLeanRunPresenterResources.resources else pure resources
  let programs := resources.programs
  let site ← (resources.forSite resourcePrefix).mapError reprStr
  -- Key by placement document and author entry, not by form instance. Keep the
  -- first source location for diagnostics; ordered maps give stable output.
  let mut bindings : PublicationBindings := {}
  for experiment in rendered do
    let provenance := s!"{experiment.program}:{experiment.sourceLine}:{experiment.sourceColumn}"
    let producer := experiment.producerModule
    -- forSite has already rejected distinct bundles with one logicalId.
    -- Preserve the original index-to-manifest mapping for identical repetitions.
    let some i := programs.findIdx? (fun bundle => bundle.descriptor.logicalId == producer)
      | throw s!"{provenance}: no published program bundle for {experiment.declaration} (producer module {producer}). Add +Module:virResourcePack to the asset library needs, embed with include_vir_assets (modules := #[Module]), and supply its ResourceSet to VersoLeanRun.publish."
    let signature ← experiment.form.expectedExport.mapError fun error =>
      s!"{provenance}: invalid compiled VIR signature: {error}"
    let binding := Lean.Json.mkObj [
      ("manifest", .str site.programManifests[i]!),
      ("expectedExport", signature)]
    bindings ← registerBinding bindings experiment binding
  let programsJson := bindings.toList.map fun document =>
    (document.1, Lean.Json.mkObj <| document.2.toList.map fun entry => (entry.1, entry.2.value))
  let mut fields : List (String × Lean.Json) := [
    ("runtimeModule", .str site.runtimeModule),
    ("runtimeManifest", .str site.runtimeManifest),
    ("programs", Lean.Json.mkObj programsJson)]
  if sequence || html then
    let some presenterIndex := programs.findIdx? (·.descriptor.logicalId == "VersoLeanRunPresenter")
      | throw "No published Lean view presenter program"
    let manifest := site.programManifests[presenterIndex]!
    let mut presenters : List (String × Lean.Json) := []
    if sequence then
      let expected ← VersoLeanRunPresenterResources.expectedMount
      presenters := presenters ++ [("sequence", Lean.Json.mkObj [
        ("manifest", .str manifest), ("declaration", .str "VersoLeanRun.Presenter.mount"),
        ("expectedExport", expected)])]
    if html then
      let expected ← VersoLeanRunPresenterResources.expectedHtml
      presenters := presenters ++ [("html", Lean.Json.mkObj [
        ("manifest", .str manifest), ("declaration", .str "VersoLeanRun.Presenter.mountHtml"),
        ("expectedExport", expected)])]
    fields := fields ++ [("presenters", Lean.Json.mkObj presenters)]
  let plan := Lean.Json.mkObj fields
  let mut files := site.files.push { path := "lean-run/publication.json", bytes := plan.compress.toUTF8 }
  for (name, contents) in [("renderer.js", include_str "../../web/renderer.js"),
      ("host.js", include_str "../../web/host.js"), ("worker.js", include_str "../../web/worker.js"),
      ("contract.js", include_str "../../web/contract.js"),
      ("presenter.js", include_str "../../web/presenter.js")] do
    files := files.push { path := "lean-run/" ++ name, bytes := contents.toUTF8 }
  return { files, plan }

/-- Write an already validated publication to the generator-selected site root. -/
def writePublication (output : System.FilePath) (publication : Publication) : IO Unit := do
  for file in publication.files do
    let path := output / file.path
    IO.FS.createDirAll (path.parent.getD output)
    IO.FS.writeBinFile path file.bytes

end VersoLeanRun
