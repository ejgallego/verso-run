module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun Verso.Output.Html
set_option compiler.postponeCompile false

public abbrev Words := Sequence String
public abbrev Markup := Verso.Output.Html
public structure Hidden where
  value : Nat

#doc (Manual) "Default model displays" =>

```leanRun (entry := words)
public def words (input : String) : Words :=
  { initial := { label := "Input", content := input, error := some "note" }
    steps := #[{ label := "Next", content := input ++ "!" }] }
```

```leanRun (entry := words)
#check (words : String → Sequence String)
#check (tests.DefaultDisplay.words.leanRun : String → SequenceView)
#guard (tests.DefaultDisplay.words.leanRun "<b>&").initial.content.render == "&lt;b&gt;&amp;"
#guard (tests.DefaultDisplay.words.leanRun "x").initial.label == "Input"
#guard (tests.DefaultDisplay.words.leanRun "x").initial.error == some "note"
#guard (tests.DefaultDisplay.words.leanRun "x").steps[0]!.content.render == "x!"
```

```leanRun (entry := htmlTrace)
public def htmlTrace (input : String) : Sequence Markup :=
  { initial := { label := "Markup", content := {{ <b> {{input}} </b> }} } }
```

```leanRun (entry := htmlMachine)
public def htmlMachine (input : String) : Automaton Markup :=
  { initial := {{ <b> {{input}} </b> }}, step := id }
```

```leanRun (entry := wordMachine)
public def wordMachine (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }
```

```leanRun (entry := custom)
public def custom (seed : Nat) : AutomatonView :=
  ({ initial := Hidden.mk seed, step := id } : Automaton Hidden).view
    (fun state => {{ <p> {{toString state.value}} </p> }})
```

```leanRun (entry := wordMachine)
#check (wordMachine : UInt64 → Automaton UInt64)
#check (tests.DefaultDisplay.wordMachine.leanRun : UInt64 → AutomatonView)
#guard (htmlTrace "<b>&").initial.content.render == "<b>&lt;b&gt;&amp;</b>"
#eval do
  let first ← Lean.Vir.RuntimeM.run (tests.DefaultDisplay.wordMachine.leanRun 18446744073709551615)
  let second ← Lean.Vir.RuntimeM.run (tests.DefaultDisplay.wordMachine.leanRun 7)
  unless first.initial.content.render == "18446744073709551615" && first.initial.label == "0" do
    throw (IO.userError "incorrect initial display")
  let next ← Lean.Vir.RuntimeM.run first.advance
  unless next.content.render == "0" && next.label == "1" do
    throw (IO.userError "incorrect wrapping transition")
  unless (← Lean.Vir.RuntimeM.run second.advance).content.render == "8" do
    throw (IO.userError "live sessions share state")
  let html ← Lean.Vir.RuntimeM.run (tests.DefaultDisplay.htmlMachine.leanRun "<b>&")
  unless html.initial.content.render == "<b>&lt;b&gt;&amp;</b>" &&
      (← Lean.Vir.RuntimeM.run html.advance).content.render == html.initial.content.render do
    throw (IO.userError "HTML was flattened or escaped twice")
```
