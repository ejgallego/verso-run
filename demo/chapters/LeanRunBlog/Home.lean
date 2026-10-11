module
public import VersoBlog
open Verso Genre Blog

#doc (Page) "Lean you can explore" =>

Run the Lean code you are reading. Change an input, inspect a computation,
or let a simulation unfold. Everything runs in your browser; you do not need
to install Lean.

# Start with an experiment

## Game of Life

A small board, a pure transition, and an SVG view. Compare a blinker with a
still life, then change the seed while the simulation keeps running.
[Explore Game of Life](../Game-of-Life/)

## A stack machine

Write a program such as `6 7 * 2 +`, then inspect the stack before and after
each instruction. Try `2 +` to see exactly where execution fails.
[Step through a stack program](../Stack-stepper/)

## Drawing with Illuminate

Change the number of nodes and watch Lean build a diagram. The displayed
source shows how Illuminate drawing commands become SVG.
[Build an Illuminate diagram](../Illuminate-diagrams/)

# Choose your format

The same runnable blocks work in all three Verso genres. Source remains
readable when JavaScript is disabled; the manual also includes it in TeX.

## Manual

Read the examples as chapters, with highlighted Lean and definition links.
[Explore the manual](../Greeting/) or [see its source anchors](../Anchored-source/).

## Blog

Use runnable code in an ordinary page or a dated article.
[Try a runnable page](page/) or [read the runnable post](notes/2026-10-8-running-lean-in-a-post/).

## Slides

Present a computation and invite the audience to change it. Leaving a slide
stops its workers.
[Try the runnable slides](../slides/).

# Write one yourself

A runnable block selects a Lean function with `entry`. Its argument type
determines the input control; its result type determines the view. Functions
can return a scalar, Verso HTML, a finite sequence, or a continuously stepping
automaton. The examples show both definitions written in a document and
checked source reused from another module.

[Get started with verso-run](https://github.com/ejgallego/verso-run).
