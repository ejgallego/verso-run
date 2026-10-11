import LeanRunBlog.Home
import LeanRunBlog.Page
import LeanRunBlog.Index
import LeanRunBlog.Post
import LeanRunBlog.Resources
import LeanRunBlog.PostResources
import VersoLeanRun.Blog.Publish

open Verso Genre Blog
open Verso.Output.Html Verso.Genre.Blog.Template

def homeTemplate : Template := do
  pure {{ <article class="demo-home">
    <h1>{{← param "title"}}</h1>
    {{← param "content"}}
  </article> }}

def demoTheme : Theme :=
  { Theme.default with cssFiles := #[("demo.css", include_str "../../web/blog-demo.css")] }
    |>.override #[] { template := homeTemplate, params := id }

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
  let resources ← IO.ofExcept <| VersoLeanRun.combineResources
    LeanRunBlog.pageResources LeanRunBlog.postResources
  let resources := if mode == "missing" then { resources with programs := #[] } else resources
  let selected ← match mode with
    | "normal" | "missing" => pure site
    | "malformed" =>
      let bad : Doc.Block Page := .other (.component `VersoLeanRun.Blog.leanRun .null) #[]
      let home := { (%doc LeanRunBlog.Home) with content := #[bad] }
      pure <| Site.page `Malformed home #[]
    | _ => throw <| IO.userError s!"Unknown Blog check {mode}"
  VersoLeanRun.Blog.blogMain demoTheme selected resources destination
