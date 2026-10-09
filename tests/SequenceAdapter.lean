module
public import VersoLeanRun
public import LeanRunSequence.Examples
public meta import LeanRunSequence.Examples
public meta import LeanRunGate.Stack
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

def rejected (value : Except String α) : Bool :=
  match value with | .ok _ => false | .error _ => true

#guard rejected (SequenceWire.validate { version := 1, frames := #[] })
#guard rejected (SequenceWire.validate { version := 2, frames := #[] })

def payloadWithFrames (count : Nat) : SequenceWire.Payload :=
  { version := 1, frames := Array.replicate count (SequenceWire.Frame.mk "Frame" "<p>State</p>" none) }

#guard !rejected (SequenceWire.validate (payloadWithFrames 128))
#guard rejected (SequenceWire.validate (payloadWithFrames 129))

-- Known operational states, independently of the native/browser agreement oracle.
#guard ((LeanRunGate.Stack.evaluate "6 7 * 2 +").steps.map (·.after)) ==
  #[[6], [7, 6], [42], [2, 42], [44]]
#guard ((LeanRunGate.Stack.evaluate "2 +").steps.back?.bind (·.error)) ==
  some "Error at '+': not enough values on the stack"
#guard ((LeanRunGate.Stack.evaluate "1 unknown").steps.back?.bind (·.error)) ==
  some "Error at 'unknown': unknown instruction or natural number"
#guard ((LeanRunGate.Stack.evaluate (" ".intercalate (List.replicate 17 "1"))).steps.back?.bind (·.error)) ==
  some "Stack or number limit reached."
#guard ((LeanRunGate.Stack.evaluate (String.ofList (List.replicate 81 '9'))).steps.back?.bind (·.error)) ==
  some "Stack or number limit reached."
#guard (LeanRunSequence.Examples.evaluate "1 2").steps.size == 2
#guard (LeanRunGate.Stack.run "1 2").endsWith "Finish with exactly one value on the stack."

#doc (Manual) "A generic sequence view" =>

```leanRun (entry := greetingSteps) (input := "Ada")
public def greetingSteps (name : String) : SequenceView :=
  let sequence : Sequence String := {
    initial := name
    steps := #[{ label := "Greeting", state := "Hello, " ++ name }] }
  sequence.view (Verso.Output.Html.text true)
```

```leanRun (entry := greetingSteps)
#check (greetingSteps.leanRunSequence : String → SequenceWire.Payload)
#guard !(rejected (SequenceWire.validate
  (greetingSteps.leanRunSequence "<b>& 世界")))
```
