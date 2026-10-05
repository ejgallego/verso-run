import LeanRunGate.Resources
import Vir.Resources.Runtime

open Vir.Resources

def main (args : List String) : IO Unit := do
  let [output] := args | throw <| IO.userError "usage: lean-run-gate OUTPUT"
  let resources : ResourceSet := { runtime := Runtime.bundle, programs := #[LeanRunGate.resources] }
  let bundles ← IO.ofExcept <| resources.bundles.mapError reprStr
  for bundle in bundles do
    let directory := System.FilePath.mk output / bundle.contentId
    IO.FS.createDirAll directory
    let manifest := "{\"contentId\":\"" ++ bundle.contentId ++ "\",\"descriptor\":" ++
      String.fromUTF8! (encodeDescriptor bundle.descriptor) ++ "}"
    IO.FS.writeFile (directory / "bundle.json") manifest
    for file in bundle.files do
      let path := directory / file.path
      IO.FS.createDirAll (path.parent.getD directory)
      IO.FS.writeBinFile path file.bytes
    IO.println s!"{bundle.descriptor.logicalId} {bundle.contentId}"

  let some modulePath := Runtime.bundle.entryPath? "runtimeModule"
    | throw <| IO.userError "runtime module role missing"
  let plan := Lean.Json.mkObj [
    ("runtime", .str (Runtime.bundle.contentId ++ "/bundle.json")),
    ("module", .str (Runtime.bundle.contentId ++ "/" ++ modulePath)),
    ("program", .str (LeanRunGate.resources.contentId ++ "/bundle.json"))]
  IO.FS.writeFile (System.FilePath.mk output / "gate-publication.json") plan.compress
