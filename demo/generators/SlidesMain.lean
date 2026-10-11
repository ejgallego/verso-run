import LeanRunSlides.Deck
import LeanRunSlides.Resources
import VersoLeanRun.Slides.Publish

open Verso Doc VersoSlides

def main (args : List String) : IO UInt32 := do
  let (mode, destination) ← match args with
    | [] => pure ("normal", ("_out/slides" : System.FilePath))
    | ["--output", path] => pure ("normal", (⟨path⟩ : System.FilePath))
    | ["--check", mode, "--output", path] => pure (mode, (⟨path⟩ : System.FilePath))
    | _ => throw <| IO.userError "usage: lean-run-slides-demo [--output DIRECTORY]"
  let resources := if mode == "missing" then
    { LeanRunSlides.resources with programs := #[] } else LeanRunSlides.resources
  let doc ← match mode with
    | "normal" | "missing" | "collision" => pure (%doc LeanRunSlides.Deck)
    | "malformed" =>
      let bad : Block VersoSlides.Slides := .other (.wrap #[
        ("data-verso-lean-run", "1"), ("data-experiment", "null")]) #[]
      pure { (%doc LeanRunSlides.Deck) with content := #[bad], subParts := #[] }
    | _ => throw <| IO.userError s!"Unknown Slides check {mode}"
  let extraCss := if mode == "collision" then
    #[({ filename := "lean-run/renderer.js", contents := ⟨"wrong bytes"⟩ } : CssFile)] else #[]
  let config : VersoSlides.Config := {
    outputDir := destination, theme := "white", center := false, height := 900,
    transition := "none", slideNumber := true, extraCss
  }
  VersoLeanRun.Slides.slidesMain config doc resources
