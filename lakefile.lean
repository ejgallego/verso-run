import Lake
open Lake DSL
require verso from "../.."
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "e92d95db62b14db88669394791f6f981161d5674"
package verso_lean_run
lean_lib LeanRunGateProgram where
  srcDir := "gates"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper]
lean_lib LeanRunGateResources where
  srcDir := "resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`@verso_lean_run/LeanRunGateResources:virResourcePack]

lean_exe «lean-run-gate» where
  root := `GateMain

input_dir leanRunWeb where
  path := "web"
  text := true

lean_lib VersoLeanRun where
  srcDir := "support"
  roots := #[`VersoLeanRun]
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-demo» where
  root := `DemoMain
  needs := #[leanRunWeb]
@[default_target]
lean_exe «lean-run-oracle» where
  root := `OracleMain

lean_lib VersoLeanRunPublish where
  srcDir := "support"
  roots := #[`VersoLeanRun.Publish]
  needs := #[leanRunWeb]

@[test_driver]
script test (args) do
  let pkg ← getRootPackage
  let result ← IO.Process.spawn {
    cwd := some pkg.dir
    cmd := "uv"
    args := #["run", "--with", "playwright", "python", "tests/acceptance.py"] ++ args.toArray
  }
  result.wait

-- This fixture elaborates, but packaging must reject its unavailable native provider.
lean_lib LeanRunGateFailures where
  srcDir := "tests/negative"
  roots := #[`UnavailableDependency]
