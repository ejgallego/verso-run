module
public import CastMathDoc
public meta import CastMathDoc
public meta import Vir.Infoview.Package
public meta import Lean.Elab.Command

open Lean Lean.Elab.Command Lean.Vir.Infoview

run_cmd do
  liftIO <| IO.FS.createDirAll "_out/cast-math"
  let env ← getEnv
  let (_, package) ← match ← liftIO <| prepareWidgetPackage "tests/CastMath.lean" env `VersoLeanRun.Cast.View with
    | .ok package => pure package
    | .error error => throwError "{error}"
  let bytes ← match Vir.GeneratePackage.emitPackage package.closure package.manifest with
    | .ok bytes => pure bytes
    | .error error => throwError "{error}"
  liftIO <| IO.FS.writeBinFile "_out/cast-math/view.irpkg" bytes

#eval IO.FS.writeFile "_out/cast-math/document.json" (Lean.toJson (%doc CastMathDoc)).compress
