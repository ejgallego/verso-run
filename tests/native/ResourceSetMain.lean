import LeanRunGate.Chapter
import LeanRunGate.Resources
import VersoLeanRun.Publish
import LeanRunSlides.Deck
import LeanRunSlides.Resources
import VersoLeanRun.Slides.Publish
import Vir.Hash

open Verso Genre Manual

private def rendered : Except String (Array VersoLeanRun.Experiment) :=
  VersoLeanRun.experiments (fun (block : Verso.Genre.Manual.Block) => do
    if block.name == `VersoLeanRun.Block.leanRun then
      return some (← Lean.fromJson? block.data)
    return none) (%doc LeanRunGate.Chapter)

/-- A valid, compatible alternative runtime with a different complete inventory. -/
private def alternateRuntime (original : Vir.Resources.Bundle) : Vir.Resources.Bundle := Id.run do
  let bytes := "resource-set runtime identity control".toUTF8
  let path := "runtime-identity-control.txt"
  let descriptor := { original.descriptor with files := original.descriptor.files.push {
    path, mediaType := "text/plain", byteLength := bytes.size, sha256 := Vir.sha256 bytes } }
  return { original with
    descriptor := descriptor
    contentId := descriptor.contentId
    files := original.files.push { path, bytes } }

private def check (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw <| IO.userError message

private def samePublication (a b : VersoLeanRun.Publication) : Bool :=
  a.plan == b.plan && (a.files.qsort (·.path < ·.path)).map (fun f => (f.path, f.bytes)) ==
    (b.files.qsort (·.path < ·.path)).map (fun f => (f.path, f.bytes))

private def identities (programs : Array Vir.Resources.Bundle) : Array (String × String) :=
  programs.map fun program => (program.descriptor.logicalId, program.contentId)

def main : IO Unit := do
  let experiments ← IO.ofExcept rendered
  let resources := LeanRunGate.resources
  let direct ← IO.ofExcept <| VersoLeanRun.preparePublication experiments resources
  let site ← IO.ofExcept <| resources.forSite "lean-run/resources" |>.mapError reprStr
  check ((← IO.ofExcept <| direct.plan.getObjValAs? String "runtimeManifest") == site.runtimeManifest)
    "publication replaced its supplied runtime"
  let nested ← IO.ofExcept <| VersoLeanRun.preparePublication experiments resources "nested/assets"
  check (nested.files.any (fun file => file.path.startsWith "nested/assets/")) "explicit resource prefix was ignored"
  let distinct ← IO.ofExcept <| VersoLeanRun.combineResources resources LeanRunSlides.resources
  check (identities distinct.programs == (identities resources.programs ++ identities LeanRunSlides.resources.programs))
    "composition changed distinct program ordering"
  let combined ← IO.ofExcept <| VersoLeanRun.combineResources resources resources
  check (combined.programs.size == 2 * resources.programs.size) "composition changed program order/count"
  let repeated ← IO.ofExcept <| VersoLeanRun.preparePublication experiments combined
  check (samePublication direct repeated) "VIR no longer deduplicates repeated resource sets"
  let malformedProgram := { resources.programs[0]! with files := #[] }
  let unchecked ← IO.ofExcept <| VersoLeanRun.combineResources resources
    { resources with programs := #[malformedProgram] }
  match VersoLeanRun.preparePublication experiments unchecked with
  | .ok _ => throw <| IO.userError "publication accepted a malformed appended program"
  | .error error => check ((error.splitOn "INVENTORY_MISMATCH").length > 1) error
  let alternate := { resources with runtime := alternateRuntime resources.runtime }
  let alternateDirect ← IO.ofExcept <| VersoLeanRun.preparePublication experiments alternate
  check (alternateDirect.plan != direct.plan) "alternate runtime identity was ignored"
  match VersoLeanRun.combineResources resources alternate with
  | .ok _ => throw <| IO.userError "different runtime identities were silently combined"
  | .error error => check (error.startsWith "RUNTIME_CONTENT_ID_CONFLICT") error
  let corrupt := { resources.runtime with files := resources.runtime.files.push {
    path := "undeclared.txt", bytes := "invalid inventory".toUTF8 } }
  match VersoLeanRun.combineResources resources { resources with runtime := corrupt } with
  | .ok _ => throw <| IO.userError "invalid repeated runtime was silently discarded"
  | .error error => check ((error.splitOn "INVENTORY_MISMATCH").length > 1) error
  let destination : System.FilePath := "_out/resource-set-runtime-rejected"
  IO.FS.createDirAll destination
  let marker := destination / "accepted.txt"
  IO.FS.writeFile marker "accepted output"
  let slidesResources := LeanRunSlides.resources
  let slidesAlternate := { slidesResources with runtime := alternateRuntime slidesResources.runtime }
  try
    let _ ← VersoLeanRun.Slides.slidesMain { outputDir := destination }
      (%doc LeanRunSlides.Deck) slidesAlternate
    throw <| IO.userError "Slides silently replaced the supplied runtime"
  catch error =>
    check ((error.toString.splitOn "RUNTIME_CONTENT_ID_CONFLICT").length > 1) error.toString
  check ((← IO.FS.readFile marker) == "accepted output") "runtime rejection modified accepted output"
  check (!(← (destination / "index.html").pathExists)) "runtime rejection created a slide site"
  IO.println "ResourceSet inventory, ordering, explicit runtime, and rejection-before-write checks passed"
