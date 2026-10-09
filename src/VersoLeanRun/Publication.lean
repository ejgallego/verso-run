/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Lean.Data.Json.Parser
public import Vir.Resources
public import Vir.Compiler.Interface.Encode
public section
open Vir.Resources
namespace VersoLeanRun

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

/-- The classifier admits one pure, homogeneous scalar callable. Encode its
retained type with VIR's canonical encoder, independently of the program bundle. -/
def FormKind.expectedExport (form : FormKind) : Except String Lean.Json := do
  let type : Vir.Interface.InterfaceType := match form.scalar with
    | .string => .string
    | .nat => .nat
    | .bool => .bool
    | .uint64 => .uint64
  let signature : Vir.Interface.ClassifiedSignature := {
    args := #[{ name := "input", type }], result := type, effect := .pure }
  Lean.Json.parse signature.toExpectedSignatureJson

/-- Plan the supplied inventory without acquiring or replacing its runtime.
Resolve declarations and validate contracts before performing any output writes. -/
def preparePublication (rendered : Array Experiment) (resources : ResourceSet)
    (resourcePrefix : String := "lean-run/resources") : Except String Publication := do
  let programs := resources.programs
  let site ← (resources.forSite resourcePrefix).mapError reprStr
  let mut bindings : Array (String × (String × Lean.Json)) := #[]
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
    bindings := bindings.push (experiment.program, (experiment.declaration, binding))
  let owners := rendered.foldl (init := #[]) fun names experiment =>
    if names.contains experiment.program then names else names.push experiment.program
  let programsJson := owners.map fun owner =>
    (owner, Lean.Json.mkObj <| (bindings.filter (·.1 == owner)).toList.map (·.2))
  let plan := Lean.Json.mkObj [
    ("runtimeModule", .str site.runtimeModule),
    ("runtimeManifest", .str site.runtimeManifest),
    ("programs", Lean.Json.mkObj programsJson.toList)]
  let mut files := site.files.push { path := "lean-run/publication.json", bytes := plan.compress.toUTF8 }
  for (name, contents) in [("renderer.js", include_str "../../web/renderer.js"),
      ("host.js", include_str "../../web/host.js"), ("worker.js", include_str "../../web/worker.js"),
      ("contract.js", include_str "../../web/contract.js")] do
    files := files.push { path := "lean-run/" ++ name, bytes := contents.toUTF8 }
  return { files, plan }

/-- Write an already validated publication to the generator-selected site root. -/
def writePublication (output : System.FilePath) (publication : Publication) : IO Unit := do
  for file in publication.files do
    let path := output / file.path
    IO.FS.createDirAll (path.parent.getD output)
    IO.FS.writeBinFile path file.bytes

end VersoLeanRun
