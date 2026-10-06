/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun
public import Vir.Resources
public import Vir.Resources.Runtime

public section
open Verso Genre Manual Vir.Resources

namespace VersoLeanRun

private partial def blockExperiments (block : Verso.Doc.Block Manual) : Except String (Array Experiment) := do
  let mut found := #[]
  let children ← match block with
    | .other container children => do
      if container.name == `VersoLeanRun.Block.leanRun then
        found := found.push (← Lean.fromJson? container.data)
      pure children
    | .concat children | .blockquote children => pure children
    | .ul items | .ol _ items => pure <| items.flatMap (·.contents)
    | .dl items => pure <| items.flatMap (·.desc)
    | _ => pure #[]
  for child in children do
    found := found ++ (← blockExperiments child)
  return found

private partial def experiments (part : Verso.Doc.Part Manual) : Except String (Array Experiment) := do
  let mut found := #[]
  for block in part.content do found := found ++ (← blockExperiments block)
  for child in part.subParts do found := found ++ (← experiments child)
  return found

/-- Publish embedded program bundles and the small worker host into either Manual output layout.
Use the locked runtime by default. Bind each rendered experiment by its actual declaration,
requiring an unambiguous recipe role; authors need no separate module-to-bundle registration.
VIR prepares the complete publication inventory. No producer files are reopened. -/
def publish (programs : Array Bundle) (runtime : Bundle := Vir.Resources.Runtime.bundle) : ExtraStep := fun mode config _ text => do
  let resources : ResourceSet := { runtime, programs }
  let site ← IO.ofExcept <| (resources.forSite "lean-run/resources").mapError reprStr
  let rendered ← IO.ofExcept <| experiments text
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
      | #[] => throw <| IO.userError s!"{provenance}: no published recipe export for {experiment.declaration}"
      | #[candidate] => pure candidate
      | _ => throw <| IO.userError s!"{provenance}: ambiguous published recipe export for {experiment.declaration}; publish one bundle and role for this declaration"
    let expected ← match experiment.shape with
      | "string" => pure "verso-string-string-v1"
      | "nat" => pure "verso-nat-nat-v1"
      | other => throw <| IO.userError s!"{provenance}: unsupported Lean Run shape {other}"
    unless entry.interfaceId == expected do
      throw <| IO.userError s!"{provenance}: resource recipe contract for {experiment.declaration} must be {expected}"
    let signature ← IO.ofExcept <| (Lean.Json.parse experiment.signature).mapError fun error =>
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
  let output := config.destination / (match mode with | .single => "html-single" | .multi => "html-multi")
  for file in site.files do
    let path := output / file.path
    IO.FS.createDirAll (path.parent.getD output)
    IO.FS.writeBinFile path file.bytes
  IO.FS.writeFile (output / "lean-run/publication.json") plan.compress
  for (name, contents) in [("renderer.js", include_str "../../web/renderer.js"),
      ("host.js", include_str "../../web/host.js"), ("worker.js", include_str "../../web/worker.js"),
      ("contract.js", include_str "../../web/contract.js")] do
    IO.FS.writeFile (output / "lean-run" / name) contents
