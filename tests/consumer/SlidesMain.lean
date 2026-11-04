import Consumer.Slides
import Consumer.SlidesResources
import VersoLeanRun.Slides.Publish
import Presenter
def main (args : List String) : IO UInt32 := do
  let [destination] := args | throw <| IO.userError "Expected output directory"
  VersoLeanRun.Slides.slidesMain { outputDir := destination, transition := "none" }
    (%doc Consumer.Slides) Consumer.slidesResources (presenters := #[Consumer.presenter])
