import ClientFixture
import ClientResources
import Vir.Resources.Site

open Lean VersoLeanRun


-- Render native reference observations for browser comparison, independently of
-- the structured VIR transport. This is test output, not an executable ABI.
def referenceFrame (frame : VersoLeanRun.Frame) : Lean.Json :=
  Lean.Json.mkObj [("label", Lean.toJson frame.label),
    ("html", Lean.toJson frame.content.render), ("error", Lean.toJson frame.error)]

def referenceSequence (view : VersoLeanRun.SequenceView) : Lean.Json :=
  Lean.Json.mkObj [("frames", Lean.toJson (view.frames.map referenceFrame))]

def main (args : List String) : IO Unit := do
  let [output] := args | throw <| IO.userError "usage: lean-run-client-check OUTPUT"
  let site ← IO.ofExcept <| ClientResources.resources.forSite "resources" |>.mapError reprStr
  let output : System.FilePath := output
  for file in site.files do
    let path := output / file.path
    IO.FS.createDirAll path.parent.get!
    IO.FS.writeBinFile path file.bytes
  let plan := Json.mkObj [
    ("runtimeModule", toJson site.runtimeModule),
    ("runtimeManifest", toJson site.runtimeManifest),
    ("programManifest", toJson site.programManifests[0]!),
    ("expectedExports", Json.mkObj [
      ("ClientFixture.trace", ← IO.ofExcept <| Json.parse ClientResources.expectedTrace),
      ("ClientFixture.start", ← IO.ofExcept <| Json.parse ClientResources.expectedStart),
      ("ClientFixture.render", ← IO.ofExcept <| Json.parse ClientResources.expectedRender)])]
  IO.FS.writeFile (output / "plan.json") plan.pretty
  IO.FS.writeFile (output / "index.html") "<!doctype html><title>Plain Lean views</title>"
  let mut cases := #[]
  for seed in #[0, 18446744073709551615] do
    let session ← Lean.Vir.RuntimeM.run (ClientFixture.start seed)
    let other ← Lean.Vir.RuntimeM.run (ClientFixture.start seed)
    let mut frames := #[session.initial]
    for _ in [:5] do frames := frames.push (← Lean.Vir.RuntimeM.run session.advance)
    cases := cases.push <| Json.mkObj [
      ("seed", toJson (toString seed)), ("trace", referenceSequence (ClientFixture.trace seed)),
      ("frames", toJson (frames.map referenceFrame)), ("independent", referenceFrame (← Lean.Vir.RuntimeM.run other.advance))]
  IO.FS.writeFile (output / "native.json") (toJson cases).pretty
