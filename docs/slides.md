# Runnable slide presentations

Import `VersoLeanRun.Slides` and use the same checked `leanRunAnchor` blocks as
Manual and Blog. Import the producer module containing the selected anchor and
its explicitly exported scalar entry:

````lean
module
public import VersoLeanRun.Slides
import MyExamples
open Verso VersoSlides VersoLeanRun.Slides

#doc (VersoSlides.Slides) "Try Lean" =>

# A greeting

```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
@[vir_export]
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

`MyExamples` must contain that exact region between `-- ANCHOR: greeting` and
`-- ANCHOR_END: greeting`. Standard Verso source matching, suggestions, cached
highlighting, and semantic entry membership remain authoritative.
See [anchor authoring](authoring.md#run-an-anchored-example-from-an-imported-module).

The adapter supplies an `ExternalCode Slides` instance using native Slides
fragmentization and code renderers. Source remains in the typed document tree;
Run uses a marked `BlockExt.wrap` with native source children and shared controls.
It does not add a new constructor to Slides' closed block enum. Proof states can
be hidden with `-showProofStates`; definition links follow native Slides policy.
Run source blocks use no side panel and no stretch, leaving room for controls.

## Publish a deck

Prepare and embed each producer with `virPrograms` and `include_vir_library`,
as in [Blog publication](blog.md#publish-a-site). Import
`VersoLeanRun.Slides.Publish` in the native generator:

```lean
def main := VersoLeanRun.Slides.slidesMain
  { outputDir := "_slides", theme := "white" }
  (%doc MyDeck) #[MyExamples.resources]
```

The wrapper collects marked metadata from the typed deck, then prepares one
resource set containing the native Slides formatter and Run producers. Both use
the stock embedded runtime and the `lib/vir/` inventory. The shared Run host and
binding plan live under `lean-run/`.

The complete inventory enters Slides' existing asset planner as binary theme
assets. Its collision checks run before any output writes. Custom themes retain
their styles and assets. Built-in themes become equivalent custom asset bundles
using the same vendored CSS and fonts, at their original paths. Existing extra
CSS, JS, and head elements are preserved. No generated HTML scraping or producer
file lookup participates in publication.

## Reveal and workers

Only Run creates its dedicated worker on invocation. The native Slides formatter
keeps its existing initialization behavior. A slide change or hidden fragment
terminates affected Run workers, cancels pending acquisition, clears outputs and
HTML previews, and rejects stale completion. Returning to the slide or revealing
the fragment permits a fresh invocation. Hidden forms cannot submit.
Mobile scroll navigation follows the same cancellation rules. When resizing out
of scroll view makes Reveal restore its saved HTML, detached workers are disposed
and the new controls are attached to fresh hosts.

Inputs own Enter, arrows, and Space while focused, so typing and submitting do
not navigate Reveal. `+collapsed` uses a source disclosure after enhancement.
Without JavaScript, the deck becomes a readable static document with visible
source and disabled controls. This slice adds no Slides TeX backend.

The scalar boundary is shared: pure `String → String` and `Nat → Nat` exports.
HTML uses a producer-owned String serialization wrapper, as in Blog; isolated
previews preserve escaping. Inline definition elaboration remains Manual-only.

## Compatibility and demo

The selected Slides snapshot is
[`235aac80`](https://github.com/ejgallego/verso-slides/commit/235aac80e627c11e4f094ced7e4e564ed5ecfe93),
on Lean 4.34.0 and VIR `bda79d5c` / runtime `e415…`. It is a public review snapshot,
not a claim that its upstream landing is complete. Our existing Verso pin is
its required `cad4b633` plus the small Manual highlighting hook, so adding Slides
does not change any existing dependency pin.

`lake exe lean-run-slides-demo` generates `_out/slides`. The combined
`python3 scripts/build-demo-site.py` puts the deck under `_out/html-multi/slides`
and links all three genres from the landing page. The deck reuses the existing
Helper and Blog producers for exact Nat, Unicode greetings, real Stop, and HTML.
