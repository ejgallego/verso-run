/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Blog
public import VersoLeanRun.Collect
public import VersoLeanRun.Publication

public section
open Verso Doc Genre Blog Template

namespace VersoLeanRun.Blog

private def decodeExperiment (block : BlockExt) : Except String (Option Experiment) := do
  match block with
  | .component name data =>
    if name != `VersoLeanRun.Blog.leanRun then return none
    let .arr #[experiment] := data
      | throw "Invalid Blog Lean Run metadata: expected one experiment"
    return some (← Lean.fromJson? experiment)
  | _ => return none

/-- Use the same draft predicate as VersoBlog.Generate.writeBlog. Hidden posts
must not require callable bundles or contribute execution bindings. -/
private def blogExperiments (text : Part Page) (posts : Array BlogPost)
    (showDrafts : Bool) : Except String (Array Experiment) := do
  let mut found ← experiments decodeExperiment text
  for post in posts do
    if post.contents.metadata.map (·.draft) == some true && !showDrafts then continue
    found := found ++ (← experiments decodeExperiment post.contents)
  return found

private partial def dirExperiments (dir : Dir) (showDrafts : Bool) : Except String (Array Experiment) := do
  match dir with
  | .page _ _ text children =>
    let mut found ← experiments decodeExperiment text
    for child in children do found := found ++ (← dirExperiments child showDrafts)
    return found
  | .blog _ _ text posts => blogExperiments text posts showDrafts
  | .static .. => return #[]

/-- Collect from typed Page/Post trees with the generator's draft policy,
never rendered HTML. Drafts are excluded unless explicitly requested. -/
def siteExperiments (site : Site) (showDrafts : Bool := false) : Except String (Array Experiment) := do
  match site with
  | .page _ text children =>
    let mut found ← experiments decodeExperiment text
    for child in children do
      if child.name == "lean-run" then throw "Blog directory 'lean-run' is reserved for execution resources"
      found := found ++ (← dirExperiments child showDrafts)
    return found
  | .blog _ text posts => blogExperiments text posts showDrafts

/-- Stock Blog generation plus the shared validated binary inventory. Destination
and draft policy are explicit; the supplied runtime and inventory are preserved. -/
def blogMainResources (theme : Theme) (site : Site) (resources : Vir.Resources.ResourceSet)
    (destination : System.FilePath := "_site") (showDrafts : Bool := false)
    (components : Components := by exact %registered_components)
    (linkTargets : Verso.Code.LinkTargets TraverseContext := {}) : IO UInt32 := do
  let found ← IO.ofExcept <| siteExperiments site showDrafts
  let publication ← IO.ofExcept <| preparePublicationWithResources found resources
  let options := ["--output", destination.toString] ++ (if showDrafts then ["--drafts"] else [])
  let result ← Verso.Genre.Blog.blogMain theme site linkTargets options (components := components)
  if result == 0 then writePublication destination publication
  return result

/-- Compatibility adapter for the original Bundle-based Blog generator. -/
def blogMain (theme : Theme) (site : Site) (programs : Array Vir.Resources.Bundle)
    (destination : System.FilePath := "_site") (showDrafts : Bool := false)
    (runtime : Vir.Resources.Bundle := Vir.Resources.Runtime.bundle)
    (components : Components := by exact %registered_components)
    (linkTargets : Verso.Code.LinkTargets TraverseContext := {}) : IO UInt32 :=
  blogMainResources theme site { runtime, programs } destination showDrafts components linkTargets

end VersoLeanRun.Blog
