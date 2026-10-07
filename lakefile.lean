import Lake
open Lake DSL
require verso from git "https://github.com/ejgallego/verso" @ "3f6366aa8045b342b0b68c0373a8ebfce7d5611f"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "1ed079ca2ab8306ae877ed4920f7d55d392365f8"
require illuminate from git "https://github.com/leanprover/illuminate" @ "a1a61c9678da010e958ed24cdfa6f635b85f172a"
package verso_vir
lean_lib LeanRunGateProgram where
  srcDir := "gates"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper]
lean_lib LeanRunGateResources where
  srcDir := "resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`@verso_vir/LeanRunGateResources:virResourcePack]

lean_exe «lean-run-gate» where
  root := `GateMain

lean_exe «lean-run-publication-check» where
  root := `PublicationMain

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
