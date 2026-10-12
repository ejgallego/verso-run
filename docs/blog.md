# Runnable Blog pages and posts

Run blocks work in both Blog `Page` and `Post` documents. Import
`VersoLeanRun.Blog` and open its namespace alongside `Verso.Genre.Blog`.
A simple example defines its function inside a `leanRun` block:

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

The same block works in a `Post` with its usual date and author metadata. Definitions,
namespaces, and open declarations remain available in later Run blocks in that document.
A later block can select an existing function and show `#check Demo.greet`.
The build registers each function named by `entry`. Pages and posts use the
same Run controls and keep Blog's code formatting.

Definitions in Blog's ordinary `leanInit` and `lean` blocks belong to separate
named example contexts. They are not automatically available in Run blocks.
A runnable function must be defined in the document or imported from a module.

Shared functions can be imported and selected with `leanRun`, displaying a
reference such as `#check MyExamples.greet`. See
[reusing an imported function](authoring.md#reuse-a-function-from-an-imported-module)
for a complete example and publication setup.

## Optional shared source anchors

`leanRunAnchor` displays a checked quotation of an imported implementation. This
is useful when a walkthrough explains the function's body:

````lean
```leanRunAnchor greeting (project := ".") (module := MyExamples) (entry := MyExamples.greet) (input := "Ada")
public def MyExamples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

Import `MyExamples` into the document. Its source region must be between
`-- ANCHOR: greeting` and `-- ANCHOR_END: greeting`, and the displayed body must
match. The function named by `entry` must be defined within that region. Verso's
usual highlighting, proof states, and hover information remain available.
If the quotation no longer matches the source, Verso reports an error and
suggests a replacement. See
[anchor authoring](authoring.md#run-an-anchored-example-from-an-imported-module).

## Publish a site

Use a Page as the site root, with blogs in child directories, as the demo does.
In the pinned Verso version, generating a `Site.blog` root fails because its blog
traversal registration is missing. Root collection and publication planning are
tested directly; nested blogs are tested through native generation.


`blogMain` omits draft posts by default, so their program bundles are not required
for publication. Pass `(showDrafts := true)` to include drafts and register their
bundles along with those of the visible documents.


For each Page or Post containing a Run block, declare `+Module:virResourcePack` in `needs`, and embed with
`include_vir_assets (modules := #[Module])`. See [resource wiring](internals.md#resource-ownership-and-site-integration). Import
`VersoLeanRun.Blog.Publish` in the native site generator and call:

```lean
def main : IO UInt32 := do
  let resources ← IO.ofExcept <| VersoLeanRun.combineResources MyPage.resources MyPost.resources
  VersoLeanRun.Blog.blogMain Theme.default mySite resources (destination := "_site")
```

`blogMain` takes a Blog `Site`, a theme, a complete `ResourceSet`, and a destination.
Optional arguments control draft visibility, components, and link targets.
Resource sets with different runtime identities cannot be combined. The wrapper
validates the resources before generating the site, then writes its execution
assets under the reserved `lean-run/` directory.

Blog's components provide the shared script and stylesheet. Renderer links work
from nested posts and copied sites, including when a theme sets a `<base>` URL.
Without JavaScript, source remains readable and controls stay disabled.
Blog has no TeX backend.

## HTML and interaction

Blog supports the same [function types and controls](authoring.md#the-result-type-chooses-the-display)
as Manual. `+multiline` gives String inputs a textarea; Enter adds a newline,
and Ctrl+Enter or ⌘+Enter runs the example. `Html` results appear in an isolated
preview, while String results remain plain text. No `output` argument or VIR
annotation is required. The [demo functions](../demo/chapters/LeanRunBlog/Examples.lean)
show both result types.

Input, collapsed source, Stop, and retry behave as described in the authoring
guide. Blog keeps its own links and code formatting; Manual's `defSite` option
does not apply here.

## Demo layout

`lake exe lean-run-blog-demo` produces `_out/blog`, with an overview, a runnable
Page, and a dated Post. `python3 scripts/build-demo-site.py` generates the combined
site under `_out/html-multi`: the overview becomes the landing page, Blog lives
under `blog/`, Slides lives under `slides/`, and existing Manual chapter URLs
remain available. The landing links to runnable examples in all three genres.

Run functions can also return recorded or live views; see
[sequences](authoring.md#present-a-sequence-of-states) and
[automata](authoring.md#run-an-automaton-continuously).
