/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun
public import Vir.Resources

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

/-- Publish compiled resources and the small worker host into either Manual output layout.
Each program is paired with its actual owning module's name. Check every rendered experiment
against the recipe before writing execution assets; no producer files are reopened. -/
def publish (runtime : Bundle) (programs : Array (String × Bundle)) : ExtraStep := fun mode config _ text => do
  let resources : ResourceSet := { runtime, programs := programs.map (·.2) }
  let bundles ← IO.ofExcept <| resources.bundles.mapError reprStr
  let rendered ← IO.ofExcept <| experiments text
  for experiment in rendered do
    let provenance := s!"{experiment.program}:{experiment.sourceLine}:{experiment.sourceColumn}"
    let some (_, program) := programs.find? (·.1 == experiment.program)
      | throw <| IO.userError s!"{provenance}: no compiled Lean Run program for {experiment.declaration}"
    let some entry := program.descriptor.exports.find? (·.declaration == experiment.declaration)
      | throw <| IO.userError s!"{provenance}: {experiment.declaration} is not in the program's resource recipe"
    let expected ← match experiment.shape with
      | "string" => pure "verso-string-string-v1"
      | "nat" => pure "verso-nat-nat-v1"
      | other => throw <| IO.userError s!"{provenance}: unsupported Lean Run shape {other}"
    unless entry.interfaceId == expected do
      throw <| IO.userError s!"{provenance}: resource recipe contract for {experiment.declaration} must be {expected}"
  let output := config.destination / (match mode with | .single => "html-single" | .multi => "html-multi")
  let base := "lean-run/resources/"
  for bundle in bundles do
    let directory := output / base / bundle.contentId
    IO.FS.createDirAll directory
    let manifest := "{\"contentId\":\"" ++ bundle.contentId ++ "\",\"descriptor\":" ++
      String.fromUTF8! (encodeDescriptor bundle.descriptor) ++ "}"
    IO.FS.writeFile (directory / "bundle.json") manifest
    for file in bundle.files do
      let path := directory / file.path
      IO.FS.createDirAll (path.parent.getD directory)
      IO.FS.writeBinFile path file.bytes
  let some runtimeModule := runtime.entryPath? "runtimeModule"
    | throw <| IO.userError "missing VIR runtime module"
  let programsJson ← programs.mapM fun (moduleName, program) => do
    let exportsJson ← program.descriptor.exports.mapM fun item => do
      let mut fields := [
        ("role", Lean.Json.str item.role),
        ("manifest", .str (base ++ program.contentId ++ "/bundle.json"))]
      if let some experiment := rendered.find? fun e =>
          e.program == moduleName && e.declaration == item.declaration then
        let signature ← IO.ofExcept <| (Lean.Json.parse experiment.signature).mapError fun error =>
          s!"{moduleName}:{experiment.sourceLine}:{experiment.sourceColumn}: invalid compiled VIR signature: {error}"
        fields := fields ++ [("expectedExport", Lean.Json.mkObj [
          ("declaration", .str item.declaration), ("interfaceId", .str item.interfaceId),
          ("signature", signature)])]
      return (item.declaration, Lean.Json.mkObj fields)
    return (moduleName, Lean.Json.mkObj exportsJson.toList)
  let plan := Lean.Json.mkObj [
    ("runtimeModule", .str (base ++ runtime.contentId ++ "/" ++ runtimeModule)),
    ("runtimeManifest", .str (base ++ runtime.contentId ++ "/bundle.json")),
    ("programs", Lean.Json.mkObj programsJson.toList)]
  IO.FS.writeFile (output / "lean-run/publication.json") plan.compress
  for (name, contents) in [("renderer.js", include_str "../../web/renderer.js"),
      ("host.js", include_str "../../web/host.js"), ("worker.js", include_str "../../web/worker.js"),
      ("contract.js", include_str "../../web/contract.js")] do
    IO.FS.writeFile (output / "lean-run" / name) contents
