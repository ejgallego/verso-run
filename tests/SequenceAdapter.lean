module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

def rejected (value : Except String α) : Bool :=
  match value with | .ok _ => false | .error _ => true

#guard rejected (SequenceWire.decode "{\"version\":1,\"frames\":[]}")
#guard rejected (SequenceWire.decode "{\"version\":2,\"frames\":[]}")

#doc (Manual) "A generic sequence view" =>

```leanRun (entry := greetingSteps) (input := "Ada")
public def greetingSteps (name : String) : SequenceView :=
  let sequence : Sequence String := {
    initial := name
    steps := #[{ label := "Greeting", state := "Hello, " ++ name }] }
  sequence.view (Verso.Output.Html.text true)
```

```leanRun (entry := greetingSteps)
#check (greetingSteps.leanRunSequence : String → String)
#guard !(rejected (SequenceWire.decode
  (greetingSteps.leanRunSequence "<b>& 世界")))
```
