# Authoring runnable examples

For a complete working project, start with the
[Manual starter](../examples/manual-starter/README.md). This guide explains the
blocks you add to its chapter.

## A basic block

Import `VersoLeanRun` into a module chapter and disable postponed compilation for
executable examples:

````lean
module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "My runnable chapter" =>

```leanRun (entry := Demo.greet)
@[vir_export]
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name
```
````

`entry` is mandatory and resolves through Lean's actual declaration identity and the
retained example scopes. Scalar declarations must carry `@[vir_export]`. VIR classifies
their interfaces; this form admits pure, monomorphic `String → String` and `Nat → Nat`,
each with one explicit argument. A public `String → Verso.Output.Html` function is adapted
automatically, without an author-side `@[vir_export]` marker. Missing, unmarked, private,
unsupported, non-executable, and unavailable standard-runtime dependencies have negative
tests. Other block arguments, including `-keep` and `+error`, are rejected. Ordinary
`lean` blocks retain their existing behavior.

## Input and source display

The optional `(input := "...")` argument supplies the form's initial text, without running
it on page load. For example, the stack calculator uses `(input := "6 7 * 2 +")`. Readers
can edit or clear it normally, and ordinary input validation still applies when they run
it.

For a longer example, `+collapsed` puts its source in a native expandable “View Lean
implementation” panel. It starts closed so the input is easy to reach; readers can open it
with a mouse or keyboard, including without JavaScript. The source remains fully present
in HTML and TeX, and all declarations are still elaborated and retained normally.

## HTML results

Scalar output defaults to plain text. `(output := "html")` requires a String result and
displays the markup in an isolated, sandboxed frame. Typed HTML entries select this mode
automatically; explicit `output := "text"` is rejected. This preview supports static HTML,
inline CSS, and data images; scripts and external embedded resources are disabled. String
functions interpolating reader input into markup should escape it for the chosen context.
Typed HTML functions can use Verso’s HTML syntax to escape text and attributes
automatically; raw HTML nodes remain an explicit author choice. Input edits, Stop, pending
calls and failures clear the previous preview. Runtime errors remain plain text, and the
result-size limit still applies. The frame has a fixed height with scrolling for larger
documents.

For a typed HTML entry, the block generates a public `String → String` wrapper named
`<entry>.leanRunHtml`, calling `Verso.Output.Html.asString`. Select this wrapper in the
VIR recipe, while the block's `entry` stays the original function:

````lean
```leanRun (entry := Demo.card) (input := "Ada")
open Verso.Output.Html
public def Demo.card (name : String) : Verso.Output.Html :=
  {{ <h2> "Hello, " {{name}} "!" </h2> }}
```
````

```json
{ "role": "card", "declaration": "Demo.card.leanRunHtml",
  "interfaceId": "verso-string-string-v1" }
```

The generated wrapper receives the usual `vir_export` validation, including its
compiled dependency closure. Repeated placements reuse it; conflicting declarations
at that name produce an author diagnostic. Neither VIR's ABI nor the renderer changes.

## Run an anchored example from an imported module

The current checkout also provides `leanRunAnchor`. It displays a standard Verso
source anchor and runs an explicitly selected function without redeclaring it in
the document. The independently pinned starter currently demonstrates the older
inline API; using anchors requires an extension revision containing this feature.

In a producer module such as `Examples.Arithmetic`, mark the source region:

```lean
module
public meta import Vir.Attributes

-- ANCHOR: twice
@[vir_export]
public def Examples.twice (n : Nat) : Nat := n + n
-- ANCHOR_END: twice
```

Import that module into the document, then include the checked source:

````lean
```leanRunAnchor twice (project := ".") (module := Examples.Arithmetic) (entry := Examples.twice) (input := "21")
@[vir_export]
public def Examples.twice (n : Nat) : Nat := n + n
```
````

The function must be defined inside the selected anchor, public, executable, and
marked for VIR. The block body must match the source region; stale or empty
bodies receive Verso's usual replacement/fill-in suggestions. Anchor comments
are omitted from the display. This first version requires the document's own
project and an imported scalar producer; separate-project execution and automatic
typed HTML adapter generation are not qualified here. A producer-owned exported
`String → String` HTML serialization wrapper can use `(output := "html")`.

Prepare a resource recipe owned by the producer module, naming the actual entry
and corresponding scalar interface ID, then supply its embedded bundle to
`VersoLeanRun.publish`. A chapter recipe cannot export an imported producer's
root. The anchor name does not replace the entry or recipe declaration. Keep the
producer separate from the chapter that loads its highlighting, and from the
resource carrier. The [demo chapter](../gates/LeanRunGate/Chapter.lean)
shows this arrangement with the [helper](../gates/LeanRunGate/Helper.lean).

`+collapsed`, input, and output options work as for inline forms. Standard
external-code options such as `-showProofStates` and `-defSite` remain available.
Open `Verso.Code.External` when using the ordinary `anchor` block by its short name.
Use `-defSite` for a repeated display when another block already owns the desired
definition target. Each runnable placement still gets its own worker. An ordinary
`anchor` block can display the same source without a Run form.

## Reuse and document integration

`leanRun` uses ordinary command elaboration and the shared highlighted-block constructor,
retaining source locations, hovers, and example links. The only core Verso change exposes
`toHighlightedLeanBlock` for this reuse. This standalone package leaves native
precompilation disabled pending the separate VIR native-client fix. It uses the normal
Verso package as a Git dependency.

Repeated placements may select the same declaration, for example with `#check Demo.greet`
as the displayed code. Each rendered placement has a distinct instance ID and its own
worker/runtime.


For the complete project wiring, see [the starter](../examples/manual-starter/README.md)
and [resource integration](internals.md#resource-ownership-and-site-integration).
