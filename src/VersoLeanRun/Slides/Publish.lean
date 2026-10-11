/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Slides
public import VersoLeanRun.Collect
public import VersoLeanRun.Publication

public section
open Verso Doc Output Html VersoSlides

namespace VersoLeanRun.Slides

private def decodeExperiment (block : BlockExt) : Except String (Option Experiment) := do
  let .wrap attrs := block | return none
  let marker := attrs.filter (·.1 == "data-verso-lean-run")
  if marker.isEmpty then return none
  unless marker == #[("data-verso-lean-run", "1")] do
    throw "Invalid Slides Lean Run metadata: unknown or repeated marker"
  let data := attrs.filter (·.1 == "data-experiment")
  let #[(_, json)] := data | throw "Invalid Slides Lean Run metadata: expected one experiment"
  let experiment ← (Lean.Json.parse json >>= Lean.fromJson?).mapError
    ("Invalid Slides Lean Run metadata: " ++ ·)
  return some experiment

/-- A typed collection pass independent of emitted slide markup. -/
def slideExperiments (doc : Part VersoSlides.Slides) : Except String (Array Experiment) :=
  experiments decodeExperiment doc

-- Slides' wrap attributes are native metadata until collection has finished.
-- Project only that attribute for rendering; stock source/fragment nodes remain
-- intact. Verso's rewrite covers nested lists, wrappers, and definition lists.
private def browserBlock (block : Block VersoSlides.Slides) :
    Except String (Block VersoSlides.Slides) :=
  block.rewriteOtherM
    (fun _ inline children => pure (.other inline children))
    (fun _ recurse container children => do
      let container ← match container with
        | .wrap attrs => do
          let some experiment ← decodeExperiment container | pure container
          pure <| .wrap <| attrs.map fun attr =>
            if attr.1 == "data-experiment" then
              (attr.1, experiment.browserDescription.compress)
            else attr
        | other => pure other
      return .other container (← children.mapM recurse))

private partial def browserDocument (doc : Part VersoSlides.Slides) :
    Except String (Part VersoSlides.Slides) := do
  return { doc with
    content := ← doc.content.mapM browserBlock
    subParts := ← doc.subParts.mapM browserDocument }

/-- Compose Run resources with the stock formatter inventory and collision plan.
The embedded stock runtime remains authoritative; a different supplied runtime is
rejected before generation rather than silently replaced. -/
def slidesMain (config : VersoSlides.Config) (doc : Part VersoSlides.Slides)
    (resources : Vir.Resources.ResourceSet) : IO UInt32 := do
  let found ← IO.ofExcept <| slideExperiments doc
  let resources ← IO.ofExcept <| combineResources VersoSlides.VirPrettyMResources.resources resources
  let publication ← IO.ofExcept <| preparePublication found resources "lib/vir"
  let assets := publication.files.map fun file =>
    ({ filename := file.path, contents := file.bytes } : ThemeAsset)
  let config := { config with
    extraAssets := config.extraAssets ++ assets ++ #[
      ⟨"lean-run/slides.js", (include_str "../../../web/slides.js").toUTF8⟩],
    extraCss := config.extraCss ++ #[
      { filename := "lean-run/console.css", contents := ⟨include_str "../../../web/lean-run.css"⟩ },
      { filename := "lean-run/slides.css", contents := ⟨include_str "../../../web/slides.css"⟩ }],
    extraHead := config.extraHead ++ #[
      {{ <script type="module" src="lean-run/slides.js"/> }},
      {{ <noscript><style>{{Html.text false (include_str "../../../web/slides-static.css")}}</style></noscript> }}] }
  let browserDoc ← IO.ofExcept <| browserDocument doc
  VersoSlides.slidesMain config browserDoc

end VersoLeanRun.Slides
