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

private def assetTheme (config : VersoSlides.Config) : CustomTheme :=
  match config.theme with
  | .custom theme => theme
  | .builtin name =>
    let dir := "lib/reveal.js/dist/theme/"
    { stylesheet := {
        filename := dir ++ name ++ ".css"
        contents := ⟨Vendor.rewriteGoogleFontImports (Vendor.themeCSS name |>.getD Vendor.themeBlack)⟩ },
      assets := (Vendor.themeFonts name).map (fun (path, bytes) => ⟨dir ++ path, bytes⟩),
      highlightTheme := config.highlightTheme }

/-- Compose Run resources with the stock formatter inventory and collision plan.
The embedded stock runtime remains authoritative for the deck. -/
def slidesMain (config : VersoSlides.Config) (doc : Part VersoSlides.Slides)
    (programs : Array Vir.Resources.Bundle) : IO UInt32 := do
  let found ← IO.ofExcept <| slideExperiments doc
  let publication ← IO.ofExcept <| preparePublicationWithPrefix "lib/vir" found
    (VersoSlides.VirPrettyMResources.resources.programs ++ programs)
    (runtime := VersoSlides.VirPrettyMResources.resources.runtime)
  let theme := assetTheme config
  let assets := publication.files.map fun file =>
    ({ filename := file.path, contents := file.bytes } : ThemeAsset)
  let config := { config with
    theme := .custom { theme with assets := theme.assets ++ assets ++ #[
      ⟨"lean-run/slides.js", (include_str "../../../web/slides.js").toUTF8⟩] },
    extraCss := config.extraCss ++ #[
      { filename := "lean-run/console.css", contents := ⟨include_str "../../../web/lean-run.css"⟩ },
      { filename := "lean-run/slides.css", contents := ⟨include_str "../../../web/slides.css"⟩ }],
    extraHead := config.extraHead ++ #[
      {{ <script type="module" src="lean-run/slides.js"/> }},
      {{ <noscript><style>{{Html.text false (include_str "../../../web/slides-static.css")}}</style></noscript> }}] }
  VersoSlides.slidesMain config doc

end VersoLeanRun.Slides
