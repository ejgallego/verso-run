module
public import VersoLeanRun
open Verso Genre Manual InlineLean VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "Authoring runnable examples" =>

%%%
tag := "guide-authoring"
file := "authoring"
%%%

A Run block displays Lean code alongside controls for calling a function.
The `entry` argument names the function, and its Lean type determines the input
control and result display. The document build prepares it for browser execution.

# A runnable function
%%%
tag := "guide-authoring-a-basic-block"
%%%

A `leanRun` block pairs a function with an input field and a result display.
This function returns a greeting:

```leanRun (entry := Demo.greet) (input := "Ada")
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name
```

The `entry` argument names `Demo.greet`, and `input` sets the field to `Ada`.
Run calls the function with the text in that field and displays `Hello, Ada`.
Changing the name and pressing Run again produces a new greeting.

In a Manual chapter, the definition belongs in a fence labelled `leanRun`:

````
module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "My runnable chapter" =>

```leanRun (entry := Demo.greet) (input := "Ada")
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name
```
````

{ref "guide-authoring-publishing-the-document"}[Project setup and publication]
provides the remaining files and build commands for this chapter.
{ref "guide-blog"}[Blog] and {ref "guide-slides"}[Slides] use the same block syntax
with their own adapter imports.

# Inline and imported functions
%%%
tag := "guide-authoring-choose-where-the-code-lives"
%%%

A function can be defined inside `leanRun`, as above, or
{ref "guide-authoring-reuse-a-function-from-an-imported-module"}[imported from a Lean module].
Definitions, namespaces, and open declarations in Run blocks remain available
in later Run blocks. Several blocks can call the same function with different
initial inputs; each embedded example runs independently.

The code displayed with the controls is the content of the block. For an
imported function, {ref "guide-authoring-run-an-anchored-example-from-an-imported-module"}[`leanRunAnchor`]
can display a checked quotation of its implementation. This uses source from
the document's own project and checks that the quotation still matches it.
Both block types provide the same input controls and result displays.
Ordinary `lean` blocks display code without Run controls.

# Block arguments
%%%
tag := "guide-authoring-arguments-and-defaults"
%%%

:::table +header
*
  * Argument
  * Meaning
  * Default
*
  * `(entry := My.function)`
  * Function to call
  * Required
*
  * `(input := "...")`
  * Initial reader input; does not run on page load
  * Empty String, `"0"` for Nat/UInt64, `"false"` for Bool
*
  * `+multiline`
  * A textarea for a String argument
  * Off
*
  * `+collapsed`
  * Initially folded source
  * Off
:::


`Bool` inputs use a true/false selector, with presets written as the strings
`"true"` or `"false"`. `Nat` and `UInt64` inputs accept up to 256 decimal digits,
including leading zeros. UInt64 values cannot exceed `18446744073709551615`,
and arithmetic uses Lean's normal wraparound. Values beyond JavaScript's safe
integer range remain exact.

`+multiline` displays a String input in a textarea, preserving whitespace and
blank lines. Enter adds a newline; Ctrl+Enter or ⌘+Enter runs the function.
The option is only available for String inputs. String input is limited to
4096 UTF-16 code units; result limits are described below.

`+collapsed` puts source in an expandable “View Lean implementation” panel.
Source remains present in HTML and Manual TeX, including without JavaScript.

Run blocks reject `-keep`, `+error`, and unknown arguments.

# Result types and displays
%%%
tag := "guide-authoring-the-result-type-chooses-the-display"
%%%

A `String` result appears as plain text, even when it contains markup. Return
`Lean.Html` to display HTML or SVG:

```leanRun (entry := Demo.card) (input := "Ada")
public def Demo.card (name : String) : Lean.Html :=
  html%{<h2>Hello, {name}!</h2>}
```

Lean's typed HTML syntax escapes interpolated text and attributes. Entering a
name containing `<b>&` displays those characters as text in the heading.
Raw HTML nodes remain an explicit author choice. The preview supports static
HTML, inline CSS and data images; scripts and external embedded resources are
disabled. It clears when the input changes, a new call starts, Stop is pressed,
or a call fails. Errors appear as plain text. Larger results can be scrolled
within the preview.

The supported function types are:

:::table +header
*
  * Function type
  * Result display
*
  * `String → String`, `Nat → Nat`, `Bool → Bool`, `UInt64 → UInt64`
  * Plain text
*
  * `String`, `Nat`, `Bool`, or `UInt64` → `Lean.Html`
  * An isolated HTML preview
*
  * `String`, `Nat`, `Bool`, or `UInt64` → `VersoLeanRun.Sequence α` or `SequenceView`
  * Labelled states with selection and scrubbing
*
  * `String`, `Nat`, `Bool`, or `UInt64` → `VersoLeanRun.Automaton α` or `AutomatonView`
  * A live simulation with Step, Play, Pause, and Stop
:::


Functions must be public, executable, and monomorphic, with one explicit argument.
Scalar and HTML entries, as well as sequence and automaton model functions, must
be pure; custom live views return an `AutomatonView` action. The build registers
the entry with VIR and checks the helper functions it calls. No export attribute
is required.

For a plain `Sequence α` or `Automaton α`, HTML states keep their markup;
other states need a `ToString` instance and appear as escaped text. The model type
must be fixed, rather than depend on the input value. Use `.view render` for a
custom HTML or SVG display, including model types without `ToString`.

Text results are limited to 65,536 UTF-16 code units. In HTML and frame results,
the strings share that limit, including labels, content, and errors.
Structured results also have node and depth limits; see
[execution limits](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#interaction-and-limits).

# Imported functions
%%%
tag := "guide-authoring-reuse-a-function-from-an-imported-module"
%%%

Shared functions can live in ordinary Lean modules. For example,
`Examples/Arithmetic.lean` can contain:

```
module
public def Examples.twice (n : Nat) : Nat := n + n
```

The document imports the module and selects its function with `leanRun`:

````
module
public import VersoLeanRun
import Examples.Arithmetic
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "Shared arithmetic" =>

```leanRun (entry := Examples.twice) (input := "21")
#check Examples.twice
```
````

`#check Examples.twice` asks Lean for the imported function's type. In the
published document, the source panel shows this reference, with the type
available on hover. The Run button calls `Examples.twice` with the input value.
Blog and Slides support imported functions in the same way.
Several documents can reuse one implementation without adding source markers or
quoting its body.

Publish the *document module's* resource bundle for both imported and inline functions.
It includes the selected function and its compiled dependencies; the source
module needs no VIR export marker or separate bundle registration. Imported
functions use the same controls and result displays as inline definitions.
See {ref "guide-authoring-publishing-the-document"}[Project setup and publication] for the project setup
and the publishers for each genre.

# Project setup and publication
%%%
tag := "guide-authoring-publishing-the-document"
%%%

The {ref "guide-authoring-a-basic-block"}[greeting chapter] can become a small
standalone project. Install
[elan](https://github.com/leanprover/elan) and create a directory for these five
files. The toolchain and dependency are pinned together in this recipe;
copy these values into the project as shown.

`lean-toolchain`:

```
leanprover/lean4:v4.36.0-rc1
```

`lakefile.lean`:

```
import Lake
open Lake DSL

require verso_run from git
  "https://github.com/ejgallego/verso-run" @
  "2365399b99a140a3caff690fa1b00ced58dc0b73"

package my_manual

lean_lib MyChapter where
  roots := #[`MyChapter]

lean_lib MyResources where
  roots := #[`MyResources]
  needs := #[`+MyChapter:virResourcePack]

@[default_target]
lean_exe «my-manual» where
  root := `Main
```

Save the complete chapter from {ref "guide-authoring-a-basic-block"}[A runnable function]
as `MyChapter.lean`, beside the Lake file. It contains the imports, `#doc`
declaration, and greeting function. Keep `compiler.postponeCompile false` in
runnable document modules.

The document build compiles its selected functions and their dependencies into
a resource bundle. The `needs` entry prepares that bundle before compiling a
separate module that embeds it:

`MyResources.lean`:

```
module
public import Vir.Resources.Assets

public def MyResources.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[MyChapter])
```

The native generator imports both the chapter and its resources. The chapter
must not import `MyResources`, since that would create a build dependency cycle.
Pass the complete `include_vir_assets` result to the publisher:

`Main.lean`:

```
import MyChapter
import MyResources
import VersoLeanRun.Publish

open Verso Genre Manual

def main := manualMain (%doc MyChapter)
  (extraSteps := [VersoLeanRun.publish MyResources.resources])
```

Run these commands from the directory containing the five files. Code blocks
scroll horizontally when a line does not fit:

```
lake update
lake build
lake exe my-manual --output _out
python3 -m http.server 8795 --bind 127.0.0.1 \
  --directory _out/html-multi
```

Open [http://127.0.0.1:8795/](http://127.0.0.1:8795/) and press Run to display
`Hello, Ada`. Lake acquires the matching runtime; no separate Wasm build is
needed. Keep the generated `lake-manifest.json` with the project to record its
resolved dependencies.

The separate [Manual starter](https://github.com/ejgallego/verso-run/blob/main/examples/manual-starter/README.md)
targets an older release. Follow its own README and linked guide when copying
that project.

Additional chapters follow the same pattern: register their document libraries,
add their resource prerequisites and include their modules in the resource set.
For other genres, use the {ref "guide-blog-publish-a-site"}[Blog site] or
{ref "guide-slides-publish-a-deck"}[Slides deck] publisher. The
[resource integration notes](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#resource-ownership-and-site-integration)
explain how the build and publication steps fit together.

# Checked source quotations
%%%
tag := "guide-authoring-run-an-anchored-example-from-an-imported-module"
%%%

`leanRunAnchor` displays a checked quotation of an imported implementation. It
checks that the selected function is defined in the quoted region and that the
quotation matches the source. The same `Examples/Arithmetic.lean` module can
provide such a region with standard Verso source markers:

```
module
-- ANCHOR: twice
public def Examples.twice (n : Nat) : Nat := n + n
-- ANCHOR_END: twice
```

Import the source module into the document. Verso's project and module defaults
can shorten repeated blocks:

````
import Examples.Arithmetic
set_option verso.exampleProject "."
set_option verso.exampleModule "Examples.Arithmetic"

```leanRunAnchor twice (entry := Examples.twice) (input := "21")
public def Examples.twice (n : Nat) : Nat := n + n
```
````

Explicit `(project := ".")` and `(module := Examples.Arithmetic)` arguments remain
available. The entry must be defined in the selected anchor, public and executable.
The body must match the source region. Verso suggests a replacement when the
body is stale and can fill in an empty body. Anchor comments are not displayed.

The quotation stays in the document's source file. When the implementation
changes, stale quoted code fails the build until it is updated; Verso's replacement
suggestion supplies the current source. A region can contain several declarations,
and `entry` selects the one to run.

Anchored calls use the same document-owned resource bundles described above.
Checked runnable anchors require the source module to belong to the document's
own project.

Input, `+multiline` and `+collapsed` work across Manual, Blog and Slides. Standard
source options such as `-showProofStates` and `-defSite` remain available. Open
`Verso.Code.External` for the ordinary `anchor` block. Use `-defSite` on repeated
Manual displays when another block already owns the desired definition target.
An ordinary `anchor` can show the same source without a Run form.

`leanRun` defines or reuses a function directly in any of the three genres.
Namespaces, open declarations, and definitions remain available in later Run blocks.
`leanRunAnchor` is optional when the document needs a checked source quotation.
Each genre retains native source styling and links. See
{ref "guide-blog"}[Blog authoring] and {ref "guide-slides"}[Slides authoring].

# Recorded sequences
%%%
tag := "guide-authoring-present-a-sequence-of-states"
%%%

A sequence records labelled states that readers can browse in either direction.
An automaton computes each new state on demand. Both are optional helpers for
functions that need more than a single result.

The models can live in an ordinary Lean module, with no document directives or
publication setup:

```
module
public import VersoLeanRun.Views
open VersoLeanRun
```

For example, this function records two text frames:

```lean -keep
public def Demo.greetingSteps
    (name : String) : VersoLeanRun.Sequence String :=
  { initial := { label := "Start", content := name }
    steps := #[{ label := "Greeting",
                 content := "Hello, " ++ name }] }
```

The document imports that module and uses the same `leanRun` fence as for other
functions:

````
```leanRun (entry := Demo.greetingSteps) (input := "Ada")
#check Demo.greetingSteps
```
````

The result provides step selection and a scrubber. Selecting a frame displays a
recorded value; it does not rerun the computation. Input edits, Stop, and leaving
the example clear its view. The [stack-machine demo](../Stack-stepper/)
shows a longer trace with a display for each instruction.

A displayed sequence contains 1–128 frames. Labels, content, and error messages
share the 65,536 UTF-16 code unit result limit. Oversized results are rejected
rather than shortened. Frame content uses the same isolated preview as HTML
results; labels and errors appear as text.

The [Finite sequences reference](../api/VersoLeanRun/Sequence/) explains
construction, mapping, and rendering. It includes `Sequence.iterate`, which
records repeated applications of a transition, and
[error views](../api/VersoLeanRun/Sequence/#Errors) for inputs that cannot
produce a recording.

# Live automata
%%%
tag := "guide-authoring-run-an-automaton-continuously"
%%%

An `Automaton α` holds an initial state and a pure transition `α → α`. This
counter adds one whenever the reader advances:

```lean -keep
public def counter
    (seed : Nat) : VersoLeanRun.Automaton Nat :=
  { initial := seed, step := (· + 1) }
```

In a document that imports the counter's module, this block provides playback
controls:

````
```leanRun (entry := counter) (input := "10")
#check counter
```
````

The numeric state uses the default text display. No call to `.view` is needed.
For custom HTML or SVG, return `(counter seed).view render` from a separate entry.
The [Live automata reference](../api/VersoLeanRun/Automaton/)
shows rendering, step labels, and error reporting.

Opening the page leaves the example idle:

:::table +header
*
  * Action
  * Model and playback
*
  * Page load or first slide entry
  * Ready; no model or playback starts.
*
  * Run
  * Create the initial model, paused.
*
  * Play / Step
  * Advance continuously / advance once while paused.
*
  * Pause or hide the tab
  * Keep the model; an already requested transition may finish.
*
  * Return to the tab
  * Stay paused.
*
  * Edit input
  * Keep running the current model; edits are a draft.
*
  * Restart
  * Apply the draft to a fresh model; resume only if previously playing.
*
  * Stop or leave the example, including navigating away
  * End the run and clear the view.
:::

Hiding the tab, Stop, and leaving the example cancel any pending restart
resumption. Showing the tab again does not resume playback. Error frames display
the failure and disable Play and Step; Stop still ends the run.

Each example has independent state. An ordinary automaton computes its next state
without automatically recording the earlier ones. Cyclic replay keeps its saved
recording, and a model or custom view can retain additional data. Play waits for
each transition to finish before starting the next, with no fixed step limit.
Each frame has the same string limit and HTML preview restrictions as a sequence
result. Stop can interrupt a transition that has not finished.

The [Game of Life demo](../Game-of-Life/) computes and renders each new generation in
Lean. It keeps advancing even when the board stops changing. A sequence is more
suitable when readers need to revisit earlier states.

# Rendering and model operations
%%%
tag := "guide-authoring-map-and-replay-observations"
%%%

The [View API reference](../api/) covers operations for adapting these models:

- [Frames](../api/VersoLeanRun/Frame/) pair content with a label and an optional
  error message.
- [Finite sequences](../api/VersoLeanRun/Sequence/) support mapping and custom
  rendering without rerunning the computation.
- [Live automata](../api/VersoLeanRun/Automaton/) can record a bounded trace,
  repeat a saved sequence, or build a display from the step number and state.

HTML renderers can also use Illuminate's drawing-command/SVG output. Its full
animation compiler is not qualified on the current runtime; see the
[Illuminate support limits](https://github.com/ejgallego/verso-run/blob/main/evidence/illuminate-gates.md).

# Migration notes
%%%
tag := "guide-authoring-updating-older-examples"
%%%

For documents written against older versions:

- Remove redundant `@[vir_export]` markers and `output` options.
- Return `Html` directly from functions that previously serialized HTML to a
  `String`.
- For anchors, register the document module's resources instead of a separate
  bundle for the imported source module. Pass the complete `include_vir_assets`
  result to the publisher, as described in
  [resource integration](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#resource-ownership-and-site-integration).
