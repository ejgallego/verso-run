# Runnable slide presentations

Run blocks work in Slides with the `VersoLeanRun.Slides` adapter. The syntax is
the same as in Manual and Blog. A simple example defines its function inside
`leanRun`:

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

Definitions, namespaces, and open declarations remain available in later Run
blocks. A later block can show `#check Demo.greet` and use the same entry.
The document registers the functions named by its Run blocks. Inline definitions
need no VIR annotation or source anchor.

Run blocks keep Slides' native code formatting. In presentation mode, long slides
scroll within the slide area so their source, controls, and results remain
accessible. Reveal's scroll view retains its usual navigation.

Shared functions can be imported and selected with `leanRun`, displaying a
reference such as `#check MyExamples.greet`. See
[reusing an imported function](authoring.md#reuse-a-function-from-an-imported-module)
for a complete example and publication setup.

## Optional shared source anchors

`leanRunAnchor` displays a checked quotation of an imported implementation. This
is useful when a slide explains the function's body:

````lean
```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

`MyExamples` must contain that region between `-- ANCHOR: greeting` and
`-- ANCHOR_END: greeting`. The function named by `entry` must be defined within
that region. Verso checks that the displayed code matches the source and suggests
a replacement when it does not. Anchored proof states can be hidden with
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

`slidesMain` combines the document's programs with the assets required by the
Slides formatter. The supplied resource set must use the same VIR runtime as the
formatter; a mismatch is rejected before generation. Execution assets use
`lib/vir/`, with Run's shared scripts and publication plan under `lean-run/`.

Slides' asset planner checks for collisions before writing output. Built-in and
custom themes retain their CSS, fonts, and other assets. Extra CSS, JavaScript,
and head elements are also preserved.

## Reveal and workers

A Run block starts its worker when the reader runs the example. Leaving a slide
or hiding a fragment stops affected examples, cancels pending loads, and clears
their results and previews. Returning to the slide or revealing the fragment allows a fresh
run; hidden examples cannot run. The same rules apply to mobile scroll navigation.
If leaving scroll view makes Reveal restore saved slide HTML, the old workers are
disposed and the restored controls start fresh examples.

Focused inputs handle Enter, arrows, and Space, so typing and submitting do not
navigate the slides. After JavaScript loads, `+collapsed` places the source in a
disclosure panel.
Without JavaScript, the deck becomes a readable static document with visible
source and disabled controls. Slides has no TeX backend here.

Slides supports the same [function types and controls](authoring.md#the-result-type-chooses-the-display)
as Manual. `+multiline` gives String inputs a textarea; Enter adds a newline
without changing slides, and Ctrl+Enter or ⌘+Enter runs the example. `Html` results
appear in an isolated preview; String results remain text. No `output` argument
or VIR annotation is required. These behaviors apply to both inline and anchored
blocks.

## Compatibility and demo

Slides owns built-in theme CSS, font paths, and asset collision checks; the Run
adapter supplies only its own files. The binary-assets extension is reviewed in
[Slides PR #2](https://github.com/ejgallego/verso-slides/pull/2), rebased onto the
4.36 Slides branch. The root Lake manifest locks the shared VIR and Verso
dependencies; see the [exact dependency and runtime pins](internals.md#pinned-dependencies).

`lake exe lean-run-slides-demo` generates `_out/slides`. The combined
`python3 scripts/build-demo-site.py` puts the deck under `_out/html-multi/slides`
and links all three genres from the landing page. The demo uses shared functions
to show exact numbers, Unicode greetings, HTML results, and Stop behavior.

Run functions can also return recorded or live views; see
[sequences](authoring.md#present-a-sequence-of-states) and
[automata](authoring.md#run-an-automaton-continuously).
