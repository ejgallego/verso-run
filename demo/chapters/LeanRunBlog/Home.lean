module
public import VersoBlog
open Verso Genre Blog

#doc (Page) "Runnable Lean, wherever you write" =>

verso-run adds interactive Lean functions to Verso manuals, blog pages, and slides.
The document build compiles the functions; readers run them in their browser,
without a Lean installation. Results can be primitive values, HTML (including SVG), or
interactive views. The examples below show a few possibilities.

# Manual

A book with chapters, definition links, and source that also appears in TeX.
[Explore the manual](../Greeting/) or [see its source anchors](../Anchored-source/).
[Explore Game of Life](../Game-of-Life/) with an editable seed and generation controls.
[Step through a stack program](../Stack-stepper/) to inspect its instructions and stack.

# Blog

The Blog genre covers ordinary pages and dated posts, with the same Run controls.
[Try a runnable page](page/) or [read the runnable post](notes/2026-10-8-running-lean-in-a-post/).

# Slides

Runnable examples fit alongside highlighted code and Reveal fragments.
Run a function during a talk; leaving its slide stops the example.
[Try the runnable slides](../slides/).

# Write your own examples

The [View API reference](../api/) introduces HTML results and the optional helpers
for recorded sequences and live computations, with checked Lean examples and
links to the library source.
