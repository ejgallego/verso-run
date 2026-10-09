import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "f2a1491257b8ad0c71b0468abf909c6dcfda9459"

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
