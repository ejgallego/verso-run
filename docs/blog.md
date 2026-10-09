# Runnable Blog pages and posts

Import `VersoLeanRun.Blog` in a `Page` or `Post`, and open its namespace alongside
`Verso.Genre.Blog`. Use the same inline Run block as a Manual chapter:

````lean
module
public import VersoLeanRun.Blog
open Verso Genre Blog VersoLeanRun.Blog
set_option compiler.postponeCompile false

#doc (Page) "Try the function" =>

```leanRun (entry := Demo.greet) (input := "Ada")
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

The same block works in a `Post` with its normal date/author metadata. Definitions,
namespaces and open declarations persist across Run blocks in that document.
A later block can select an existing function and show `#check Demo.greet`.
Functions belong to the document module; `entry` handles export registration.
Page and Post share the native Blog code renderer and the same Run component.

Run definitions use the document environment. Blog's ordinary `leanInit`/`lean`
blocks keep their existing named example contexts; those isolated contexts are
not imported into the runnable document environment.

## Optional shared source anchors

Use `leanRunAnchor` when an ordinary imported producer is shared among several
documents. It adds Verso's checked source-region matching to the same Run behavior:

````lean
```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

Import `MyExamples` into the document. Its source region must be between
`-- ANCHOR: greeting` and `-- ANCHOR_END: greeting`, and the displayed body must
match. Standard highlighting, proof states and hover assets remain native.
Selection uses compiled declarations and semantic anchor membership, never source
text inference. See [anchor authoring](authoring.md#run-an-anchored-example-from-an-imported-module).

## Publish a site

Use a Page root with blogs in child directories, as the demo does. In the pinned
Verso revision, native generation of a `Site.blog` root fails because its blog
traversal registration is missing. Root collection and publication planning are
tested directly; nested blogs are qualified through native generation.


`blogMain` excludes draft posts by default. Its publication collector follows
the same policy as native Blog generation, so hidden drafts need no program
bundle and add no callable bindings. Pass `(showDrafts := true)` to generate
drafts and register their bundles along with the visible documents' bundles.


For each Page/Post document, declare `+Module:virResourcePack` in `needs`, and embed with
`include_vir_assets (modules := #[Module])`. See [resource wiring](internals.md#resource-ownership-and-site-integration). Import
`VersoLeanRun.Blog.Publish` in the native site generator and call:

```lean
def main : IO UInt32 := do
  let resources ← IO.ofExcept <| VersoLeanRun.combineResources MyPage.resources MyPost.resources
  VersoLeanRun.Blog.blogMain Theme.default mySite resources (destination := "_site")
```

The wrapper takes a typed Blog `Site`, a theme, a complete `ResourceSet`, an explicit
destination, and optional draft policy, components, and link targets. It preserves
the set's runtime; composition rejects different runtime identities.
It collects Page/Post AST metadata and validates the common resource plan before
calling stock Blog generation. On successful generation it writes the complete
binary inventory. It never discovers programs by scraping HTML or reopening
producer files. The root `lean-run` directory is reserved for execution assets.

Blog components contribute the shared bootstrap and CSS through Blog's normal
text-asset machinery. Every form carries a renderer URL relative to its own
page, resolved against the page URL independently of any theme's `<base>` tag.
Deep posts and copied nested sites resolve assets correctly.
Source remains readable without JavaScript; controls start
disabled until enhancement. Blog has no TeX backend.

## HTML and interaction

The shared scalar boundary admits pure `String → String`, `Nat → Nat`,
`Bool → Bool`, and `UInt64 → UInt64` exports. `+multiline` chooses a textarea
for String inputs without changing the callable signature. Enter preserves line
breaks; Ctrl+Enter or ⌘+Enter runs the example.
Return `String → Verso.Output.Html` for an HTML preview. `entry` creates a
document-owned scalar serializer automatically; a String result always displays
plain text. There is no `output` argument and no producer VIR annotation.
The [demo producer](../demo/chapters/LeanRunBlog/Examples.lean) shows this arrangement.

Input, `+collapsed`, exact Nat transport, isolated HTML previews, independent
worker ownership, actual Stop, stale-result guards, and explicit retry use the
same implementation as Manual. Blog preserves its own links and code styling;
it does not acquire Manual's `defSite` policy.

## Demo layout

`lake exe lean-run-blog-demo` produces `_out/blog`, with an overview, a runnable
Page, and a dated Post. `python3 scripts/build-demo-site.py` generates the combined
site under `_out/html-multi`: the overview becomes the landing page, Blog lives
under `blog/`, Slides lives under `slides/`, and existing Manual chapter URLs
remain available. The landing links to runnable examples in all three genres.
