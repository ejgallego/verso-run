import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "cb016c437bc566f77c01d86e2e77ba012ecfb0e4"

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
