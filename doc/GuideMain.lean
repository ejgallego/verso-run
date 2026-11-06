import VersoRunGuide
import GuideResources
import VersoLeanRun.Publish
open Verso Genre Manual

def main := manualMain (%doc VersoRunGuide)
  (config := { extraCss := {CSS.mk r#"
main pre {
  padding: 0.8em 1em;
  border: 1px solid color-mix(in srgb, currentColor 22%, transparent);
  border-radius: 0.3em;
}
/* Reserve room for heading permalinks instead of letting their absolute
   positioning extend the page beyond a narrow viewport. */
@media (max-width: 600px) {
  main .permalink-widget.inline { display: inline-block; width: 1.5em; }
}
"#} })
  (extraSteps := [VersoLeanRun.publish VersoRunGuide.resources])
