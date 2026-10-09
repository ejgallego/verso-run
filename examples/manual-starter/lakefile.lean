import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "a830999c2cc521fc59caf776e316a498b5fa7a36"

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
