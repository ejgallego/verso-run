import LeanRunBlog.Home
import LeanRunBlog.Index
import LeanRunBlog.Post
import LeanRunBlog.PostResources
import VersoLeanRun.Blog.Publish

open Verso Doc Genre Blog

/-- Exercise the same draft under a root blog and a nested blog directory. -/
def draftSite (nested : Bool) : Site := Id.run do
  let draft := { (%doc LeanRunBlog.Post) with
    metadata := (%doc LeanRunBlog.Post).metadata.map fun md => { md with draft := true } }
  let posts : Array BlogPost := #[{ id := `LeanRunBlog.Post, contents := draft }]
  if nested then
    return .page `LeanRunBlog.Home (%doc LeanRunBlog.Home)
      #[.blog "notes" `LeanRunBlog.Index (%doc LeanRunBlog.Index) posts]
  return .blog `LeanRunBlog.Index (%doc LeanRunBlog.Index) posts

/-- Hidden drafts deliberately have no program bundle. Visible drafts must have one. -/
def main (args : List String) : IO UInt32 := do
  let [placement, mode, output] := args
    | throw <| IO.userError "usage: lean-run-blog-draft-check root|nested hide|show|missing OUTPUT"
  unless placement == "root" || placement == "nested" do
    throw <| IO.userError s!"unknown placement {placement}"
  unless ["hide", "show", "missing"].contains mode do
    throw <| IO.userError s!"unknown draft policy {mode}"
  let programs := if mode == "show" then LeanRunBlog.postResources.programs else #[]
  let site := draftSite (placement == "nested")
  let showDrafts := mode != "hide"
  if placement == "root" then
    -- Pinned Verso's root-blog generator omits the blog's traversal registration.
    -- Qualify our root collector/planner directly; nested checks use real generation.
    let found ← IO.ofExcept <| VersoLeanRun.Blog.siteExperiments site showDrafts
    let publication ← IO.ofExcept <| VersoLeanRun.preparePublication found { LeanRunBlog.postResources with programs }
    VersoLeanRun.writePublication ⟨output⟩ publication
    return 0
  VersoLeanRun.Blog.blogMain Theme.default site { LeanRunBlog.postResources with programs }
    (destination := ⟨output⟩) (showDrafts := showDrafts)
