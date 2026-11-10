module
public import VersoLeanRun.Cast
public import Lean.Data.Json.Parser
public meta import VersoLeanRun.Cast

-- Asset preparation validates the complete runtime once. Widget elaboration
-- needs only its small envelope, not reconstruction of the Wasm payload.
private def runtimeManifest : Lean.Json :=
  match Lean.Json.parse (include_str "../../../.vir/infoview-runtime.json") with
  | .ok manifest => manifest
  | .error error => panic! s!"Invalid prepared infoview manifest: {error}"

public def LeanRunInfoview.widgetProps : VersoLeanRun.Cast.Props where
  wasmPath := ".vir/infoview.wasm"
  irPackage := VersoLeanRun.Cast.irPackage
  setupHint := "Run python3 scripts/setup-cast-demo.py, then restart this file's Lean server."
  runRuntimeManifest := runtimeManifest
