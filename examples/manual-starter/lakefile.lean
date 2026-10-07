import Lake
open Lake DSL

require verso_run from git "https://github.com/ejgallego/verso-run" @ "177b6c1b62783cbe279437c20b86063def28c06b"

package verso_run_starter

lean_lib StarterChapter where
  srcDir := "chapters"
  roots := #[`Starter.Chapter]

lean_lib StarterResources where
  srcDir := "resources"
  roots := #[`Starter.Resources]
  needs := #[`@verso_run_starter/StarterResources:virResourcePack]

target virPrograms (_pkg) : Array (Lean.Name × Lean.Name) := do
  return Job.pure #[(`StarterResources, `Starter.Chapter)]

@[default_target]
lean_exe «starter-manual» where
  root := `Main
