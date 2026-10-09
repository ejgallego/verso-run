# Runnable slide presentations

Import `VersoLeanRun.Slides` and use the same inline Run block as Manual or Blog:

````lean
module
public import VersoLeanRun.Slides
open Verso VersoSlides VersoLeanRun.Slides
set_option compiler.postponeCompile false

#doc (VersoSlides.Slides) "Try Lean" =>

# A greeting

```leanRun (entry := Demo.greet) (input := "Ada")
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

Definitions, namespaces and open declarations remain available in later Run
blocks. A later placement can show `#check Demo.greet` and select the same entry.
The document owns its selected callables and resource bundle. No VIR annotation
or source anchor is needed for an inline definition.

The adapter uses Slides' formatting-aware command elaborator, fragmentization
and native code renderers. Source remains in the typed document tree; Run uses
its existing marked wrapper with native source children and shared controls.
It adds no constructor to Slides' closed block enum. Run source boxes have no side
panel or stretch, leaving room for controls.

## Optional shared source anchors

Import an ordinary producer and use `leanRunAnchor` when the same source should
be displayed in several documents:

````lean
```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

`MyExamples` must contain that region between `-- ANCHOR: greeting` and
`-- ANCHOR_END: greeting`. Verso's source matching, suggestions and semantic entry
membership remain authoritative. Anchored proof states can be hidden with
`-showProofStates`; definition links follow native Slides policy. See
[anchor authoring](authoring.md#run-an-anchored-example-from-an-imported-module).

## Publish a deck

Prepare the deck through its asset library's
`+Module:virResourcePack` prerequisite, then embed with
`include_vir_assets (modules := #[Module])`,
as in [Blog publication](blog.md#publish-a-site). Import
`VersoLeanRun.Slides.Publish` in the native generator:

```lean
def main := VersoLeanRun.Slides.slidesMain
  { outputDir := "_slides", theme := "white" }
  (%doc MyDeck) MyDeck.resources
```

The wrapper collects marked metadata from the typed deck, then prepares one
resource set containing the native Slides formatter and document-selected Run
callables. The incoming set must use the same runtime content identity as the stock
formatter; mismatches are rejected before generation rather than silently
replaced. The complete inventory uses `lib/vir/`. The shared Run host and
binding plan live under `lean-run/`.

The complete inventory enters Slides' asset planner through `Config.extraAssets`.
Its collision checks run before any output writes. Custom themes retain their
styles and assets. Slides owns built-in theme CSS and fonts at their original
paths, without conversion to custom themes. Existing extra
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
source and disabled controls. Slides has no TeX backend here.

The scalar boundary is shared: pure `String → String`, `Nat → Nat`,
`Bool → Bool`, and `UInt64 → UInt64` exports. `+multiline` renders String inputs
as a textarea. Enter edits without moving Reveal; Ctrl+Enter or ⌘+Enter runs.
Return `String → Verso.Output.Html` for an automatic document-owned serializer
and isolated preview. String results remain text; no `output` argument or producer
VIR annotation is needed. Both inline and anchored blocks share these behaviors.

## Compatibility and demo

The selected [Slides snapshot](https://github.com/ejgallego/verso-slides/commit/6e514cd443a51a39d92534b5a2ef08a5e47ed262)
uses module-owned assets on Lean 4.35.0-rc4 and exposes `Config.extraAssets`
for binary additions. Slides owns built-in theme CSS, font paths, and asset
collision checks; the Run adapter supplies only its own files. The ownership
change is reviewed in [Slides PR #2](https://github.com/ejgallego/verso-slides/pull/2). The root Lake manifest locks its
shared VIR and Verso dependencies. The Verso fork supplies the Manual highlighting
hook and two upstream compiler-compatibility adjustments; Illuminate is unchanged.
See the [exact dependency and runtime pins](internals.md#pinned-dependencies).
This consumer qualification does not establish upstream integration of the Slides snapshot.

`lake exe lean-run-slides-demo` generates `_out/slides`. The combined
`python3 scripts/build-demo-site.py` puts the deck under `_out/html-multi/slides`
and links all three genres from the landing page. The deck reuses the existing
ordinary Helper, Blog and typed source functions for exact numbers, Unicode
greetings, real Stop and HTML. Its document-owned bundle exports selected wrappers.
