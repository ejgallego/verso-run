# Runnable Blog pages and posts

Import `VersoLeanRun.Blog` in a `Page` or `Post` document and open
`VersoLeanRun.Blog` alongside `Verso.Genre.Blog`. The adapter uses the same
checked `leanRunAnchor` authoring path as Manual:

````lean
module
public import VersoLeanRun.Blog
import MyExamples
open Verso Genre Blog VersoLeanRun.Blog

#doc (Page) "Try the function" =>

```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
@[vir_export]
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

The imported producer must contain that region between `-- ANCHOR: greeting`
and `-- ANCHOR_END: greeting`. Standard Verso body checks, highlighting, proof
states, and Blog hover assets remain native. Entry selection uses the compiled
declaration and semantic definition membership, not source text inference.
See [anchor authoring](authoring.md#run-an-anchored-example-from-an-imported-module).

The same block works in a `Post` with its normal date/author metadata. One
component implements both genres. Inline command elaboration through `leanRun`
remains specific to Manual in this version.

## Publish a site

Register each producer's resource owner/module pair through the normal
`virPrograms` target and embed its carrier with `include_vir_library`. Import
`VersoLeanRun.Blog.Publish` in the native site generator and call:

```lean
def main := VersoLeanRun.Blog.blogMain Theme.default mySite
  #[MyExamples.resources] (destination := "_site")
```

The wrapper takes a typed Blog `Site`, a theme, embedded bundles, an explicit
destination, and optional draft policy, runtime, components, and link targets.
It collects Page/Post AST metadata and validates the common resource plan before
calling stock Blog generation. On successful generation it writes the complete
binary inventory. It never discovers programs by scraping HTML or reopening
producer files. The root `lean-run` directory is reserved for execution assets.

Blog components contribute the shared bootstrap and CSS through Blog's normal
text-asset machinery. Every form carries a renderer URL relative to its own
page, resolved against the page URL independently of any theme's `<base>` tag.
Deep posts and copied nested sites resolve assets correctly.
Source remains readable without JavaScript; controls start
disabled until enhancement. Blog has no TeX backend in this slice.

## HTML and interaction

The shared scalar boundary admits pure `String → String` and `Nat → Nat` exports.
A producer can expose a marked String serialization wrapper around typed HTML,
then select `(output := "html")`. This keeps wrapper ownership in the producer;
automatic typed-HTML adapter creation from external source is still deferred.
The [demo producer](../gates/LeanRunBlog/Examples.lean) shows this arrangement.

Input, `+collapsed`, exact Nat transport, isolated HTML previews, independent
worker ownership, actual Stop, stale-result guards, and explicit retry use the
same implementation as Manual. Blog preserves its own links and code styling;
it does not acquire Manual's `defSite` policy.

## Demo layout

`lake exe lean-run-blog-demo` produces `_out/blog`, with an overview, a runnable
Page, and a dated Post. `python3 scripts/build-demo-site.py` generates the combined
site under `_out/html-multi`: the overview becomes the landing page, Blog lives
under `blog/`, and existing Manual chapter URLs remain available. Slides has a
planned section until its own adapter is implemented and qualified.
