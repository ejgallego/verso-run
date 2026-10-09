import Lake
open Lake DSL
require verso from git "https://github.com/ejgallego/verso" @ "aff0fc92d7b9e56a3b309d409b7ef69629af3770"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "957854b9df1202d4fadbd00ac5fa34e5adf278cc"
require illuminate from git "https://github.com/leanprover/illuminate" @ "a1a61c9678da010e958ed24cdfa6f635b85f172a"
require «verso-slides» from git "https://github.com/ejgallego/verso-slides" @ "daa96fee635f289e2be95982418483bfb4351402"
package verso_run
lean_lib LeanRunGateProgram where
  srcDir := "demo/chapters"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper]
lean_lib LeanRunGateResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`+LeanRunGate.Chapter:virResourcePack]

lean_lib LeanRunBlogExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunBlog.Examples]

lean_lib LeanRunBlogDocuments where
  srcDir := "demo/chapters"
  roots := #[`LeanRunBlog.Home, `LeanRunBlog.Page, `LeanRunBlog.Index, `LeanRunBlog.Post]

lean_lib LeanRunBlogResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunBlog.Resources]
  needs := #[`+LeanRunBlog.Page:virResourcePack]

lean_lib LeanRunSlidesDocuments where
  srcDir := "demo/chapters"
  roots := #[`LeanRunSlides.Deck]

lean_lib LeanRunTypedExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunTyped.Examples]

lean_lib LeanRunBlogPostResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunBlog.PostResources]
  needs := #[`+LeanRunBlog.Post:virResourcePack]

lean_lib LeanRunSlidesResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunSlides.Resources]
  needs := #[`+LeanRunSlides.Deck:virResourcePack]

lean_exe «lean-run-gate» where
  srcDir := "tests/native"
  root := `GateMain

lean_exe «lean-run-publication-check» where
  srcDir := "tests/native"
  root := `PublicationMain

input_dir leanRunWeb where
  path := "web"
  text := true

lean_lib VersoLeanRun where
  srcDir := "src"
  roots := #[`VersoLeanRun]
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-demo» where
  srcDir := "demo/generators"
  root := `DemoMain
  needs := #[leanRunWeb]
@[default_target]
lean_exe «lean-run-oracle» where
  srcDir := "tests/native"
  root := `OracleMain

@[default_target]
lean_exe «lean-run-blog-demo» where
  srcDir := "demo/generators"
  root := `BlogMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-blog-oracle» where
  srcDir := "tests/native"
  root := `BlogOracleMain

@[default_target]
lean_exe «lean-run-slides-demo» where
  srcDir := "demo/generators"
  root := `SlidesMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-typed-oracle» where
  srcDir := "tests/native"
  root := `TypedOracleMain

lean_lib VersoLeanRunPublish where
  srcDir := "src"
  roots := #[`VersoLeanRun.Publish]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunBlog where
  srcDir := "src"
  roots := #[`VersoLeanRun.Blog]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunSlides where
  srcDir := "src"
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
