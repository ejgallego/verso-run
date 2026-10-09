import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "c5017a9f87858c8a5def04f017e7251d4c5aa775"

package verso_run_starter

lean_lib StarterChapter where
  srcDir := "chapters"
  roots := #[`Starter.Chapter]

lean_lib StarterResources where
  srcDir := "resources"
  roots := #[`Starter.Resources]
  needs := #[`+Starter.Chapter:virResourcePack]

@[default_target]
lean_exe «starter-manual» where
  root := `Main
