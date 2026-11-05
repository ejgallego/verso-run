module
public import VersoLeanRun
import VersoRunGuide.Examples
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

# A basic block
%%%
tag := "guide-authoring-a-basic-block"
%%%

`leanRun` works in Manual, Blog pages and posts, and Slides. Each genre has its
own adapter import. A small, self-contained example defines its function inside
the block. A minimal Manual chapter looks like this:

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

`entry` names `Demo.greet`, and `input` sets the text field to `Ada`. Pressing
Run displays `Hello, Ada`. Readers can edit the name and run the function again.

Try the greeting here:

```leanRun (entry := Demo.greet) (input := "Ada")
#check Demo.greet
```

The [Manual starter](https://github.com/ejgallego/verso-run/blob/main/examples/manual-starter/README.md)
provides a complete project and commands to build and serve it locally. It uses
Lean 4.35 and an earlier verso-run API, including `Verso.Output.Html`. Follow its
README and [version-specific authoring guide](https://github.com/ejgallego/verso-run/blob/f2a1491257b8ad0c71b0468abf909c6dcfda9459/docs/authoring.md)
when copying that project. This guide describes the current Lean 4.36 checkout,
including `Lean.Html` and the sequence and automaton helpers. See
{ref "guide-hosting-share-a-complete-copy"}[Hosting and sharing] for hosting requirements.

Definitions, namespaces, and open declarations remain available in later Run
blocks. Several blocks can use the same entry; a later block might display just
`#check Demo.greet` while providing another set of controls. Each embedded
example runs independently.
Ordinary `lean` blocks display code without adding Run controls.

# Choose where the code lives
%%%
tag := "guide-authoring-choose-where-the-code-lives"
%%%

:::table +header
*
  * Goal
  * Authoring choice
*
  * Write a self-contained example
  * Define the function inside `leanRun`.
*
  * Reuse a function from a Lean module
  * {ref "guide-authoring-reuse-a-function-from-an-imported-module"}[Import the module and use `leanRun`]; display a reference such as `#check`.
*
  * Explain an implementation in this project
  * {ref "guide-authoring-run-an-anchored-example-from-an-imported-module"}[Use `leanRunAnchor`] to display a checked quotation of its source region.
:::


Both forms run and publish functions in the same way. Runnable anchors use
source from the document's own project and check that the displayed quotation
matches it. They are useful when the implementation itself belongs in the
explanation.

# Arguments and defaults
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
`"true"` or `"false"`. `Nat` and `UInt64` inputs use exact decimal values; UInt64 is bounded
by `18446744073709551615` and arithmetic uses Lean's normal wraparound. Values
beyond JavaScript's safe integer range remain exact.

`+multiline` displays a String input in a textarea, preserving whitespace and
blank lines. Enter adds a newline; Ctrl+Enter or ⌘+Enter runs the function.
The option is only available for String inputs. String input is limited to
4096 UTF-16 code units; result limits are described below.

`+collapsed` puts source in an expandable “View Lean implementation” panel.
Source remains present in HTML and Manual TeX, including without JavaScript.

Run blocks reject `-keep`, `+error`, and unknown arguments.

# The result type chooses the display
%%%
tag := "guide-authoring-the-result-type-chooses-the-display"
%%%

A `String` result appears as plain text, even when it contains markup. Return
`Lean.Html` to display HTML or SVG:

````
```leanRun (entry := Demo.card) (input := "Ada")
public def Demo.card (name : String) : Lean.Html :=
  html%{<h2>Hello, {name}!</h2>}
```
````

Lean's typed HTML syntax escapes interpolated text and attributes. Raw HTML
nodes remain an explicit author choice. The preview supports static HTML, inline
CSS and data images; scripts and external embedded resources are disabled.
The preview clears when the input changes, a new call starts, Stop is pressed,
or a call fails. Errors appear as plain text. Larger results can be scrolled
within the preview.

Try a name containing `<b>&` to see how interpolated text is escaped:

```leanRun (entry := Demo.card) (input := "Ada")
#check Demo.card
```

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

# Reuse a function from an imported module
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

The form runs the imported function; its source panel shows the `#check`
reference. Blog and Slides support imported functions in the same way.
Several documents can reuse one implementation without adding source markers or
quoting its body.

Publish the *document module's* resource bundle for both imported and inline functions.
It includes the selected function and its compiled dependencies; the source
module needs no VIR export marker or separate bundle registration. Imported
functions use the same controls and result displays as inline definitions.
See {ref "guide-authoring-publishing-the-document"}[Publishing the document] for the project setup
and the publishers for each genre.

# Publishing the document
%%%
tag := "guide-authoring-publishing-the-document"
%%%

The [Manual starter](https://github.com/ejgallego/verso-run/blob/main/examples/manual-starter/README.md) includes a complete
project and build instructions for its pinned release. For an existing project,
[resource integration](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#resource-ownership-and-site-integration)
explains the Lake configuration and generator setup. Blog and Slides use their
respective {ref "guide-blog-publish-a-site"}[site] and {ref "guide-slides-publish-a-deck"}[deck]
publishers.

The document's compiled functions and their dependencies are published together
as a resource bundle. A separate module embeds these resources for the native
generator. The generator imports both the document and its resource module;
the document must not import the resource module, since that would create a
build dependency cycle.

Pass the complete `include_vir_assets` result to the publisher. Keep
`compiler.postponeCompile false` in runnable document modules.

# Run an anchored example from an imported module
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

# Present a sequence of states
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
records repeated applications of a transition, and `SequenceView.error` for
inputs that cannot produce a recording.

# Run an automaton continuously
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

Each example has independent state and keeps only its current state. Play waits
for each transition to finish before starting the next, with no fixed step
limit. A model that grows with each step can still use more memory over time.
Each frame has the same string limit and HTML preview restrictions as a sequence
result. Stop can interrupt a transition that has not finished.

The [Game of Life demo](../Game-of-Life/) computes and renders each new generation in
Lean. It keeps advancing even when the board stops changing. A sequence is more
suitable when readers need to revisit earlier states.

# Further view operations
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

# Updating older examples
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
