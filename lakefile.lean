import Lake
open Lake DSL
require verso from git "https://github.com/ejgallego/verso" @ "3f6366aa8045b342b0b68c0373a8ebfce7d5611f"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "bda79d5c4ab7d061c971fcd8917f536393ec03ee"
require illuminate from git "https://github.com/leanprover/illuminate" @ "a1a61c9678da010e958ed24cdfa6f635b85f172a"
package verso_run
lean_lib LeanRunGateProgram where
  srcDir := "gates"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper]
lean_lib LeanRunGateResources where
  srcDir := "resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`@verso_run/LeanRunGateResources:virResourcePack]

lean_lib LeanRunHelperResources where
  srcDir := "resources"
  roots := #[`LeanRunGate.HelperResources]
  needs := #[`@verso_run/LeanRunHelperResources:virResourcePack]

target virPrograms (_pkg) : Array (Lean.Name × Lean.Name) := do
  return Job.pure #[(`LeanRunGateResources, `LeanRunGate.Chapter),
    (`LeanRunHelperResources, `LeanRunGate.Helper)]

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
