import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "90414e5f03867d5bddcc87a670a1b3b2ef0017c4"

package verso_run_starter

lean_lib StarterChapter where
  srcDir := "chapters"
  roots := #[`Starter.Chapter]

lean_lib StarterResources where
  srcDir := "resources"
  roots := #[`Starter.Resources]
  needs := #[`+Starter.Chapter, `@verso_run_starter/StarterResources:virResourcePack]

@[default_target]
lean_exe «starter-manual» where
  root := `Main
