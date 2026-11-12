module
public import CastSourceGate
public meta import Vir.Infoview.Package
public meta import Lean.Elab.Command

open Lean Lean.Elab.Command Lean.Vir.Infoview

-- Exercise imported-owner resolution for both actual authoring paths without
-- executing Lean code on the server or substituting saved IR for a live page.
run_cmd do
  liftIO <| IO.FS.createDirAll "_out/rc2-demo"
  let env ← getEnv
  for (root, file) in #[(`inlineEcho, "inline"), (`CastSourceGate.LeanRunInfoview.double.leanRun, "anchor")] do
    let prepared ← liftIO <| prepareWidgetPackage "tests/cast/CastSourceGate.lean" env root
    let (_, package) ← match prepared with
      | .ok package => pure package
      | .error error => throwError "Cannot prepare {root}: {error}"
    let bytes ← match Vir.GeneratePackage.emitPackage package.closure package.manifest with
      | .ok bytes => pure bytes
      | .error error => throwError "{error}"
    liftIO <| IO.FS.writeBinFile s!"_out/rc2-demo/{file}.irpkg" bytes
    logInfo m!"PASS compiled {root} ({bytes.size} bytes)"
