module
public import CastSourceGate
public meta import CastSourceGate
public meta import Vir.Infoview.Package
public meta import Lean.Elab.Command

open Lean Lean.Elab.Command Lean.Vir.Infoview

run_cmd do
  liftIO <| IO.FS.createDirAll "_out/cast-placement"
  let env ← getEnv
  let (_, package) ← match ← liftIO <| prepareWidgetPackage "tests/CastPlacement.lean" env `VersoLeanRun.Cast.View with
    | .ok package => pure package
    | .error error => throwError "{error}"
  let bytes ← match Vir.GeneratePackage.emitPackage package.closure package.manifest with
    | .ok bytes => pure bytes
    | .error error => throwError "{error}"
  liftIO <| IO.FS.writeBinFile "_out/cast-placement/view.irpkg" bytes

#eval IO.FS.writeFile "_out/cast-placement/document.json" (Lean.toJson (%doc CastSourceGate)).compress
