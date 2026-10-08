import LeanRunSlides.Deck
import LeanRunBlog.Resources
import LeanRunGate.HelperResources
import VersoLeanRun.Slides.Publish

open Verso Doc VersoSlides

def main (args : List String) : IO UInt32 := do
  let (mode, destination) ← match args with
    | [] => pure ("normal", ("_out/slides" : System.FilePath))
    | ["--output", path] => pure ("normal", (⟨path⟩ : System.FilePath))
    | ["--check", mode, "--output", path] => pure (mode, (⟨path⟩ : System.FilePath))
    | _ => throw <| IO.userError "usage: lean-run-slides-demo [--output DIRECTORY]"
  let programs := if mode == "missing" then #[LeanRunGate.helperResources]
    else #[LeanRunGate.helperResources, LeanRunBlog.resources]
  let doc ← match mode with
    | "normal" | "missing" | "collision" => pure (%doc LeanRunSlides.Deck)
    | "malformed" =>
      let bad : Block VersoSlides.Slides := .other (.wrap #[
        ("data-verso-lean-run", "1"), ("data-experiment", "null")]) #[]
      pure { (%doc LeanRunSlides.Deck) with content := #[bad], subParts := #[] }
    | _ => throw <| IO.userError s!"Unknown Slides check {mode}"
  let extraCss := if mode == "collision" then
    #[({ filename := "lean-run/renderer.js", contents := ⟨"wrong bytes"⟩ } : CssFile)] else #[]
  VersoLeanRun.Slides.slidesMain {
    outputDir := destination, theme := "white", center := false,
    transition := "none", slideNumber := true, extraCss
  } doc programs
