import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "55ebf56b49616462a81195efe1cbc1d1480dc088"

package verso_run_starter

lean_lib StarterChapter where
  srcDir := "chapters"
  roots := #[`Starter.Chapter]

lean_lib StarterResources where
  srcDir := "resources"
  roots := #[`Starter.Resources]
  needs := #[`@verso_run_starter/StarterResources:virResourcePack]

@[default_target]
lean_exe «starter-manual» where
  root := `Main
