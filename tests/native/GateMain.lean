import LeanRunGate.Resources
import Vir.Resources

open Vir.Resources

def main (args : List String) : IO Unit := do
  let [output] := args | throw <| IO.userError "usage: lean-run-gate OUTPUT"
  let resources := LeanRunGate.resources
  let site ← IO.ofExcept <| (resources.forSite "").mapError reprStr
  for file in site.files do
    let path := System.FilePath.mk output / file.path
    IO.FS.createDirAll (path.parent.getD (System.FilePath.mk output))
    IO.FS.writeBinFile path file.bytes
  let plan := Lean.Json.mkObj [
    ("runtime", .str site.runtimeManifest),
    ("module", .str site.runtimeModule),
    ("program", .str site.programManifests[0]!)]
  IO.FS.writeFile (System.FilePath.mk output / "gate-publication.json") plan.compress
