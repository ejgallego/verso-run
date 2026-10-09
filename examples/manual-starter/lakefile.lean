import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "fa66aeee1a6f9707a70684f9034d8838a7eda1d4"

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
