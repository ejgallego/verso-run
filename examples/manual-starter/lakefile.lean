import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "6442617de8ddb052e664a1b52e50e6413b28385a"

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
