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
  a.plan == b.plan && a.files.map (fun f => (f.path, f.bytes)) == b.files.map (fun f => (f.path, f.bytes))

def main : IO Unit := do
  let experiments ← IO.ofExcept rendered
  let resources := LeanRunGate.resources
  let direct ← IO.ofExcept <| VersoLeanRun.preparePublicationWithResources experiments resources
  let legacy ← IO.ofExcept <| VersoLeanRun.preparePublication experiments resources.programs resources.runtime
  check (samePublication direct legacy) "legacy/default publication changed"
  let nested ← IO.ofExcept <| VersoLeanRun.preparePublicationWithResources experiments resources "nested/assets"
  let legacyNested ← IO.ofExcept <| VersoLeanRun.preparePublicationWithPrefix
    "nested/assets" experiments resources.programs resources.runtime
  check (samePublication nested legacyNested) "legacy explicit-prefix publication changed"
  let combined ← IO.ofExcept <| VersoLeanRun.combineResources resources resources
  check (combined.programs.size == 2 * resources.programs.size) "composition changed program order/count"
  let repeated ← IO.ofExcept <| VersoLeanRun.preparePublicationWithResources experiments combined
  check (samePublication direct repeated) "VIR no longer deduplicates repeated resource sets"
  let alternate := { resources with runtime := alternateRuntime resources.runtime }
  let alternateDirect ← IO.ofExcept <| VersoLeanRun.preparePublicationWithResources experiments alternate
  let alternateLegacy ← IO.ofExcept <| VersoLeanRun.preparePublication experiments resources.programs alternate.runtime
  check (samePublication alternateDirect alternateLegacy) "supplied compatible runtime was replaced"
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
    let _ ← VersoLeanRun.Slides.slidesMainResources { outputDir := destination }
      (%doc LeanRunSlides.Deck) slidesAlternate
    throw <| IO.userError "Slides silently replaced the supplied runtime"
  catch error =>
    check ((error.toString.splitOn "RUNTIME_CONTENT_ID_CONFLICT").length > 1) error.toString
  check ((← IO.FS.readFile marker) == "accepted output") "runtime rejection modified accepted output"
  check (!(← (destination / "index.html").pathExists)) "runtime rejection created a slide site"
  IO.println "ResourceSet compatibility, explicit runtime, deduplication, and rejection-before-write checks passed"
