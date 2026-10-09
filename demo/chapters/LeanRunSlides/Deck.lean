module
public import VersoLeanRun.Slides
import LeanRunSequence.Examples
import LeanRunGate.Helper
import LeanRunBlog.Examples
import LeanRunTyped.Examples

open Verso Doc VersoSlides VersoLeanRun.Slides

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (VersoSlides.Slides) "Lean you can run" =>

# Exact natural numbers

Edit the input and choose Run. Try `9007199254740993`: Lean keeps the exact value.
Use the arrows to change slides.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

# A greeting, on reveal

Advance once to reveal the example. Its worker stops when the fragment is hidden.

:::fragment
```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
:::

# Stop when you leave

Run `1000000000000`, then choose Stop or move to another slide.

```leanRunAnchor counting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10") +collapsed
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

# An HTML card

The same isolated HTML preview works in a slide.

```leanRunAnchor card (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.card) (input := "Ada") +collapsed
public def LeanRunBlog.Examples.card (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}
```

# A Boolean choice

Choose true or false, then Run.

```leanRunAnchor flip (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.flip)
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
```

# Exact UInt64

Try `9007199254740993`, then the maximum `18446744073709551615`.
Incrementing the maximum wraps to zero.

```leanRunAnchor increment (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.increment)
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
```

# Multiline String

Enter adds a line break; Ctrl+Enter or ⌘+Enter runs the example.

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline +collapsed
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
```

# Define a runnable function here

The same inline Run syntax works in a deck. Its source uses native Slides rendering.

:::fragment
```leanRun (entry := LeanRunSlides.Deck.Inline.greet) (input := "Ada")
namespace LeanRunSlides.Deck.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
:::

# Reuse the inline definition

The namespace and definition remain available in later blocks.

```leanRun (entry := greet) (input := "Grace") +collapsed
#check greet
```

# Inline typed HTML

```leanRun (entry := LeanRunSlides.Deck.Inline.card) (input := "Ada") +collapsed
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunSlides.Deck.Inline
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +") +collapsed
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```
