/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Lean.Data.Json.Parser
public import Vir.Resources
public import Vir.Resources.Runtime
public import VersoLeanRunPresenterResources
public section
open Vir.Resources
namespace VersoLeanRun

/-- Complete validated inventory, ready for a genre's output or asset planner. -/
structure Publication where
  files : Array File
  plan : Lean.Json

/-- Resolve declarations and validate contracts before performing any output writes. -/
def preparePublicationWithPrefix (resourcePrefix : String)
    (rendered : Array Experiment) (programs : Array Bundle)
    (runtime : Bundle := Vir.Resources.Runtime.bundle) : Except String Publication := do
  let sequence := rendered.any (·.output == "sequence")
  let programs := if sequence then programs.push VersoLeanRunPresenterResources.bundle else programs
  let resources : ResourceSet := { runtime, programs }
  let site ← (resources.forSite resourcePrefix).mapError reprStr
  let mut bindings : Array (String × (String × Lean.Json)) := #[]
  for experiment in rendered do
    let provenance := s!"{experiment.program}:{experiment.sourceLine}:{experiment.sourceColumn}"
    let producer := if experiment.producerModule.isEmpty then experiment.program else experiment.producerModule
    -- forSite has already rejected distinct bundles with one logicalId.
    -- Preserve the original index-to-manifest mapping for identical repetitions.
    let some i := programs.findIdx? (fun bundle => bundle.descriptor.logicalId == producer)
      | throw s!"{provenance}: no published program bundle for {experiment.declaration} (producer module {producer}). Add +Module:virResourcePack to the asset library needs, embed with include_vir_assets (modules := #[Module]), and supply its bundle to VersoLeanRun.publish."
    let signature ← (Lean.Json.parse experiment.signature).mapError fun error =>
      s!"{provenance}: invalid compiled VIR signature: {error}"
    let binding := Lean.Json.mkObj [
      ("manifest", .str site.programManifests[i]!),
      ("expectedExport", signature)]
    bindings := bindings.push (experiment.program, (experiment.declaration, binding))
  let owners := rendered.foldl (init := #[]) fun names experiment =>
    if names.contains experiment.program then names else names.push experiment.program
  let programsJson := owners.map fun owner =>
    (owner, Lean.Json.mkObj <| (bindings.filter (·.1 == owner)).toList.map (·.2))
  let mut fields : List (String × Lean.Json) := [
    ("runtimeModule", .str site.runtimeModule),
    ("runtimeManifest", .str site.runtimeManifest),
    ("programs", Lean.Json.mkObj programsJson.toList)]
  if sequence then
    let expected ← (Lean.Json.parse VersoLeanRunPresenterResources.expectedMount).mapError id
    fields := fields ++ [("presenters", Lean.Json.mkObj [("sequence", Lean.Json.mkObj [
      ("manifest", .str site.programManifests[programs.size - 1]!),
      ("declaration", .str "VersoLeanRun.Presenter.mount"),
      ("expectedExport", expected)])])]
  let plan := Lean.Json.mkObj fields
  let mut files := site.files.push { path := "lean-run/publication.json", bytes := plan.compress.toUTF8 }
  for (name, contents) in [("renderer.js", include_str "../../web/renderer.js"),
      ("host.js", include_str "../../web/host.js"), ("worker.js", include_str "../../web/worker.js"),
      ("contract.js", include_str "../../web/contract.js"),
      ("sequence.js", include_str "../../web/sequence.js")] do
    files := files.push { path := "lean-run/" ++ name, bytes := contents.toUTF8 }
  return { files, plan }

/-- Preserve the original publication API and default inventory root. -/
def preparePublication (rendered : Array Experiment) (programs : Array Bundle)
    (runtime : Bundle := Vir.Resources.Runtime.bundle) : Except String Publication :=
  preparePublicationWithPrefix "lean-run/resources" rendered programs runtime

/-- Write an already validated publication to the generator-selected site root. -/
def writePublication (output : System.FilePath) (publication : Publication) : IO Unit := do
  for file in publication.files do
    let path := output / file.path
    IO.FS.createDirAll (path.parent.getD output)
    IO.FS.writeBinFile path file.bytes

end VersoLeanRun
