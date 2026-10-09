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

private partial def dirExperiments (dir : Dir) : Except String (Array Experiment) := do
  match dir with
  | .page _ _ text children =>
    let mut found ← experiments decodeExperiment text
    for child in children do found := found ++ (← dirExperiments child)
    return found
  | .blog _ _ text posts =>
    let mut found ← experiments decodeExperiment text
    for post in posts do found := found ++ (← experiments decodeExperiment post.contents)
    return found
  | .static .. => return #[]

/-- Collect from typed Page/Post trees, never rendered HTML. -/
def siteExperiments (site : Site) : Except String (Array Experiment) := do
  match site with
  | .page _ text children =>
    let mut found ← experiments decodeExperiment text
    for child in children do
      if child.name == "lean-run" then throw "Blog directory 'lean-run' is reserved for execution resources"
      found := found ++ (← dirExperiments child)
    return found
  | .blog _ text posts =>
    let mut found ← experiments decodeExperiment text
    for post in posts do found := found ++ (← experiments decodeExperiment post.contents)
    return found

/-- Stock Blog generation plus the shared validated binary inventory. Destination
and draft policy are explicit, so publication and generation cannot select different roots. -/
def blogMain (theme : Theme) (site : Site) (programs : Array Vir.Resources.Bundle)
    (destination : System.FilePath := "_site") (showDrafts : Bool := false)
    (runtime : Vir.Resources.Bundle := Vir.Resources.Runtime.bundle)
    (components : Components := by exact %registered_components)
    (linkTargets : Verso.Code.LinkTargets TraverseContext := {}) : IO UInt32 := do
  let found ← IO.ofExcept <| siteExperiments site
  let publication ← IO.ofExcept <| preparePublication found programs runtime
  let options := ["--output", destination.toString] ++ (if showDrafts then ["--drafts"] else [])
  let result ← Verso.Genre.Blog.blogMain theme site linkTargets options (components := components)
  if result == 0 then writePublication destination publication
  return result

end VersoLeanRun.Blog
