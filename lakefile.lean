import Lake
open Lake DSL
require verso from git "https://github.com/ejgallego/verso" @ "3f6366aa8045b342b0b68c0373a8ebfce7d5611f"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "fb5af64788e419affa4a496b144f7f96bed48322"
require illuminate from git "https://github.com/leanprover/illuminate" @ "a1a61c9678da010e958ed24cdfa6f635b85f172a"
require «verso-slides» from git "https://github.com/ejgallego/verso-slides" @ "35b5d14bc97d71981d01957f8a6fc6ea7470a6e4"
package verso_run
lean_lib LeanRunGateProgram where
  srcDir := "gates"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper]
lean_lib LeanRunGateResources where
  srcDir := "resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`+LeanRunGate.Chapter, `@verso_run/LeanRunGateResources:virResourcePack]

lean_lib LeanRunBlogExamples where
  srcDir := "gates"
  roots := #[`LeanRunBlog.Examples]

lean_lib LeanRunBlogDocuments where
  srcDir := "gates"
  roots := #[`LeanRunBlog.Home, `LeanRunBlog.Page, `LeanRunBlog.Index, `LeanRunBlog.Post]

lean_lib LeanRunBlogResources where
  srcDir := "resources"
  roots := #[`LeanRunBlog.Resources]
  needs := #[`+LeanRunBlog.Page, `@verso_run/LeanRunBlogResources:virResourcePack]

lean_lib LeanRunSlidesDocuments where
  srcDir := "gates"
  roots := #[`LeanRunSlides.Deck]

lean_lib LeanRunTypedExamples where
  srcDir := "gates"
  roots := #[`LeanRunTyped.Examples]

lean_lib LeanRunBlogPostResources where
  srcDir := "resources"
  roots := #[`LeanRunBlog.PostResources]
  needs := #[`+LeanRunBlog.Post, `@verso_run/LeanRunBlogPostResources:virResourcePack]

lean_lib LeanRunSlidesResources where
  srcDir := "resources"
  roots := #[`LeanRunSlides.Resources]
  needs := #[`+LeanRunSlides.Deck, `@verso_run/LeanRunSlidesResources:virResourcePack]

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

@[default_target]
lean_exe «lean-run-blog-demo» where
  root := `BlogMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-blog-oracle» where
  root := `BlogOracleMain

@[default_target]
lean_exe «lean-run-slides-demo» where
  root := `SlidesMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-typed-oracle» where
  root := `TypedOracleMain

lean_lib VersoLeanRunPublish where
  srcDir := "support"
  roots := #[`VersoLeanRun.Publish]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunBlog where
  srcDir := "support"
  roots := #[`VersoLeanRun.Blog]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunSlides where
  srcDir := "support"
  roots := #[`VersoLeanRun.Slides]
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
