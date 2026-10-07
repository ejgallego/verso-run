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
public section
open Vir.Resources
namespace VersoLeanRun

/-- Complete validated inventory, ready for a genre's output or asset planner. -/
structure Publication where
  files : Array File
  plan : Lean.Json

/-- Resolve declarations and validate contracts before performing any output writes. -/
def preparePublication (rendered : Array Experiment) (programs : Array Bundle)
    (runtime : Bundle := Vir.Resources.Runtime.bundle) : Except String Publication := do
  let resources : ResourceSet := { runtime, programs }
  let site ← (resources.forSite "lean-run/resources").mapError reprStr
  let mut bindings : Array (String × (String × Lean.Json)) := #[]
  for experiment in rendered do
    let provenance := s!"{experiment.program}:{experiment.sourceLine}:{experiment.sourceColumn}"
    -- Repeated references to the same bundle/role are one candidate. Distinct
    -- recipes or roles selecting the same declaration require an explicit choice.
    let mut candidates : Array (Nat × ProgramExport) := #[]
    for i in [:programs.size] do
      for entry in programs[i]!.descriptor.exports do
        if entry.declaration == experiment.declaration && !candidates.any (fun (j, previous) =>
            programs[j]!.contentId == programs[i]!.contentId && previous.role == entry.role) then
          candidates := candidates.push (i, entry)
    let (i, entry) ← match candidates with
      | #[] => throw s!"{provenance}: no published recipe export for {experiment.declaration}. Add the declaration to your resource recipe and register its bundle with VersoLeanRun.publish."
      | #[candidate] => pure candidate
      | _ => throw s!"{provenance}: ambiguous published recipe export for {experiment.declaration}; publish one bundle and role for this declaration"
    let expected ← match experiment.shape with
      | "string" => pure "verso-string-string-v1"
      | "nat" => pure "verso-nat-nat-v1"
      | other => throw s!"{provenance}: unsupported Lean Run shape {other}"
    unless entry.interfaceId == expected do
      throw s!"{provenance}: resource recipe contract for {experiment.declaration} must be {expected}; found {entry.interfaceId}. Update this declaration's interfaceId in the resource recipe."
    let signature ← (Lean.Json.parse experiment.signature).mapError fun error =>
      s!"{provenance}: invalid compiled VIR signature: {error}"
    let binding := Lean.Json.mkObj [
      ("role", .str entry.role), ("manifest", .str site.programManifests[i]!),
      ("expectedExport", Lean.Json.mkObj [
        ("declaration", .str entry.declaration), ("interfaceId", .str entry.interfaceId),
        ("signature", signature)])]
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
