module
public import VersoRunGuide.Authoring
public import VersoRunGuide.Blog
public import VersoRunGuide.Slides
public import VersoRunGuide.Hosting
public import VersoRunGuide.Troubleshooting
open Verso Genre Manual

#doc (Manual) "The verso-run guide" =>

%%%
shortTitle := "verso-run"
%%%

verso-run runs Lean functions interactively from compiled Verso documents.
Functions can return primitive values, HTML or SVG, and recorded or live views.
Authors define the computation and its display in Lean; readers supply inputs
and run the published examples in their browser.

Start with {ref "guide-authoring"}[a runnable block], then use the setup for
{ref "guide-blog"}[Blog] or {ref "guide-slides"}[Slides] when working in those genres.
The guide also covers {ref "guide-hosting"}[hosting] and
{ref "guide-troubleshooting"}[diagnosing errors].

The [View API reference](../api/) documents the ordinary Lean library and its
checked examples. [Explore the demos](../) for runnable Manual, Blog, and Slides
examples. Contributor instructions and implementation notes remain in the
[repository](https://github.com/ejgallego/verso-run).

{include 0 VersoRunGuide.Authoring}

{include 0 VersoRunGuide.Blog}

{include 0 VersoRunGuide.Slides}

{include 0 VersoRunGuide.Hosting}

{include 0 VersoRunGuide.Troubleshooting}
