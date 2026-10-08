import LeanRunBlog.Home
import LeanRunBlog.Page
import LeanRunBlog.Index
import LeanRunBlog.Post
import LeanRunBlog.Resources
import LeanRunGate.HelperResources
import VersoLeanRun.Blog.Publish

open Verso Genre Blog

def site : Site := .page `LeanRunBlog.Home (%doc LeanRunBlog.Home) #[
  .page "page" `LeanRunBlog.Page (%doc LeanRunBlog.Page) #[],
  .blog "notes" `LeanRunBlog.Index (%doc LeanRunBlog.Index)
    #[{id := `LeanRunBlog.Post, contents := %doc LeanRunBlog.Post}]]

def main (args : List String) : IO UInt32 := do
  let (mode, destination) ← match args with
    | [] => pure ("normal", ("_out/blog" : System.FilePath))
    | ["--output", path] => pure ("normal", (⟨path⟩ : System.FilePath))
    | ["--check", mode, "--output", path] => pure (mode, (⟨path⟩ : System.FilePath))
    | _ => throw <| IO.userError "usage: lean-run-blog-demo [--output DIRECTORY]"
  let programs := if mode == "missing" then #[LeanRunGate.helperResources]
    else #[LeanRunGate.helperResources, LeanRunBlog.resources]
  let selected ← match mode with
    | "normal" | "missing" => pure site
    | "malformed" =>
      let bad : Doc.Block Page := .other (.component `VersoLeanRun.Blog.leanRun .null) #[]
      let home := { (%doc LeanRunBlog.Home) with content := #[bad] }
      pure <| Site.page `Malformed home #[]
    | _ => throw <| IO.userError s!"Unknown Blog check {mode}"
  VersoLeanRun.Blog.blogMain Theme.default selected programs destination
