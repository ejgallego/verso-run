import Lake
open Lake DSL

-- VIR's source revision also selects its locked browser runtime.
require verso from git "https://github.com/ejgallego/verso" @ "aff0fc92d7b9e56a3b309d409b7ef69629af3770"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @ "957854b9df1202d4fadbd00ac5fa34e5adf278cc"
require illuminate from git "https://github.com/leanprover/illuminate" @ "a1a61c9678da010e958ed24cdfa6f635b85f172a"
require «verso-slides» from git "https://github.com/ejgallego/verso-slides" @ "6e514cd443a51a39d92534b5a2ef08a5e47ed262"

package verso_run

-- Browser files are embedded by the public library. Tracking the directory makes
-- edits invalidate its consumers even when Lean source is unchanged.

input_dir leanRunWeb where
  path := "web"
  text := true

-- Each module has one owner. Namespace roots would also claim descendants in
-- other libraries, rejoining the client and authoring build boundaries.

lean_lib VersoLeanRunViews where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun.Views, .one `VersoLeanRun.Frame,
    .one `VersoLeanRun.Sequence, .one `VersoLeanRun.Automaton]

lean_lib VersoLeanRunAuthoring where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun.Model, .one `VersoLeanRun.Callable,
    .one `VersoLeanRun.Anchored, .one `VersoLeanRun.Inline,
    .one `VersoLeanRun.Render, .one `VersoLeanRun.Collect]

-- Genre authoring and native publication retain their public imports.

lean_lib VersoLeanRun where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun, .one `VersoLeanRun.Manual]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunPublish where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun.Publish, .one `VersoLeanRun.Publication]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunBlog where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun.Blog, .one `VersoLeanRun.Blog.Publish]
  needs := #[leanRunWeb]

lean_lib VersoLeanRunSlides where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRun.Slides, .one `VersoLeanRun.Slides.Publish]
  needs := #[leanRunWeb]

-- The browser presenter is separate from its native resource carrier.
lean_lib VersoLeanRunPresenter where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRunPresenter, .one `VersoLeanRun.Preview]

lean_lib VersoLeanRunPresenterResources where
  srcDir := "src"
  roots := #[]
  globs := #[.one `VersoLeanRunPresenterResources]
  needs := #[`+VersoLeanRunPresenter:virResourcePack]

-- Demo documents and ordinary Lean producers. They never import their carriers.

lean_lib LeanRunGateProgram where
  srcDir := "demo/chapters"
  roots := #[`LeanRunGate.Chapter, `LeanRunGate.Helper, `LeanRunGate.Stack]

lean_lib LeanRunBlogExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunBlog.Examples]

lean_lib LeanRunBlogDocuments where
  srcDir := "demo/chapters"
  roots := #[`LeanRunBlog.Home, `LeanRunBlog.Page, `LeanRunBlog.Index, `LeanRunBlog.Post]

lean_lib LeanRunSlidesDocuments where
  srcDir := "demo/chapters"
  roots := #[`LeanRunSlides.Deck]

lean_lib LeanRunTypedExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunTyped.Examples]

lean_lib LeanRunSequenceExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunSequence.Examples, `LeanRunSequence.Life]

lean_lib LeanRunRenderedExamples where
  srcDir := "demo/chapters"
  roots := #[`LeanRunRendered.Examples]

-- Prepare module-owned packs before embedding them in disjoint carrier libraries.
-- Keep the graph acyclic: document → module resource facet → carrier → generator.

lean_lib LeanRunGateResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunGate.Resources]
  needs := #[`+LeanRunGate.Chapter:virResourcePack]

lean_lib LeanRunBlogResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunBlog.Resources]
  needs := #[`+LeanRunBlog.Page:virResourcePack]

lean_lib LeanRunBlogPostResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunBlog.PostResources]
  needs := #[`+LeanRunBlog.Post:virResourcePack]

lean_lib LeanRunSlidesResources where
  srcDir := "demo/resources"
  roots := #[`LeanRunSlides.Resources]
  needs := #[`+LeanRunSlides.Deck:virResourcePack]

-- Demo generators retain their existing default targets.

@[default_target]
lean_exe «lean-run-demo» where
  srcDir := "demo/generators"
  root := `DemoMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-blog-demo» where
  srcDir := "demo/generators"
  root := `BlogMain
  needs := #[leanRunWeb]

@[default_target]
lean_exe «lean-run-slides-demo» where
  srcDir := "demo/generators"
  root := `SlidesMain
  needs := #[leanRunWeb]

-- Native references and qualification tools; oracles retain their default targets.

-- A plain Lean client, with no Verso document or authoring adapter.
lean_lib LeanRunClientFixture where
  srcDir := "tests/client"
  roots := #[`ClientFixture]

lean_lib LeanRunClientResources where
  srcDir := "tests/client"
  roots := #[`ClientResources]
  needs := #[`+ClientFixture:virResourcePack]

lean_exe «lean-run-client-check» where
  srcDir := "tests/client"
  root := `ClientMain

script «check-library-ownership» do
  let pkg ← getRootPackage
  let source := pkg.dir / "src"
  for path in ← source.walkDir do
    if path.extension == some "lean" then
      let relative := path.toString.dropPrefix? (source.toString ++ "/")
      let some relative := relative | throw <| IO.userError s!"Unexpected source path: {path}"
      let name := (System.FilePath.mk relative.toString).withExtension ""
        |>.components.foldl Lean.Name.str Lean.Name.anonymous
      let owners := pkg.leanLibs.filter (·.isBuildableModule name)
      unless owners.size == 1 do
        throw <| IO.userError s!"{name} needs one library owner, found {owners.map (·.name)}"
  IO.println "Every library source module has exactly one Lake owner"
  return 0

@[default_target]
lean_exe «lean-run-oracle» where
  srcDir := "tests/native"
  root := `OracleMain

@[default_target]
lean_exe «lean-run-blog-oracle» where
  srcDir := "tests/native"
  root := `BlogOracleMain

@[default_target]
lean_exe «lean-run-typed-oracle» where
  srcDir := "tests/native"
  root := `TypedOracleMain

lean_exe «lean-run-publication-check» where
  srcDir := "tests/native"
  root := `PublicationMain

lean_exe «lean-run-blog-draft-check» where
  srcDir := "tests/native"
  root := `BlogDraftMain

-- Resource inventory checks execute natively: they hash complete embedded packs.
lean_exe «lean-run-resource-set-check» where
  srcDir := "tests/native"
  root := `ResourceSetMain

-- This fixture elaborates, but packaging must reject its unavailable native provider.

lean_lib LeanRunGateFailures where
  srcDir := "tests/negative"
  roots := #[`UnavailableDependency]

-- The acceptance driver builds fixtures as needed. Run mutation checks sequentially.

@[test_driver]
script test (args) do
  let pkg ← getRootPackage
  -- Keep test caches inside the checkout; callers can still select their own.
  let uvCache ← IO.getEnv "UV_CACHE_DIR"
  let pythonCache ← IO.getEnv "UV_PYTHON_INSTALL_DIR"
  let result ← IO.Process.spawn {
    env := #[
      ("UV_CACHE_DIR", some (uvCache.getD (pkg.dir / ".cache/uv").toString)),
      ("UV_PYTHON_INSTALL_DIR", some (pythonCache.getD (pkg.dir / ".cache/uv-python").toString))]
    cwd := some pkg.dir
    cmd := "uv"
    args := #["run", "--with", "playwright", "python", "tests/acceptance.py"] ++ args.toArray
  }
  result.wait
