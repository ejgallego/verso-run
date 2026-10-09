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

-- The initial state is present even for zero transitions. Rendering never calls
-- the transition, and custom labels describe the same iteration indices.
def successors := Sequence.iterate (· + 2) (3 : Nat) 3 (fun i => s!"State {i}")
#guard successors.initial.state == 3
#guard successors.initial.label == "State 0"
#guard successors.steps.map (·.state) == #[5, 7, 9]
#guard successors.steps.map (·.label) == #["State 1", "State 2", "State 3"]
#guard (Sequence.iterate Bool.not true 0).steps.isEmpty
#guard (Sequence.iterate Bool.not true 0).initial.state
#guard (Sequence.iterate Bool.not true 3).steps.map (·.state) == #[false, true, false]
#guard (Sequence.iterate Bool.not true 0 |>.view fun _ => .empty).toPayload.frames.size == 1
#guard (SequenceView.error "No initial model").toPayload.frames.size == 1
#guard (SequenceView.error "No initial model").initial.html.asString == ""
#guard (SequenceView.error "No initial model").initial.error == some "No initial model"

public abbrev TraceView := SequenceView

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
public def greetingSteps (name : String) : TraceView :=
  let sequence : Sequence String := {
    initial := { label := "Start", state := name }
    steps := #[{ label := "Greeting", state := "Hello, " ++ name }] }
  sequence.view (Verso.Output.Html.text true)
```

```leanRun (entry := greetingSteps)
#check (greetingSteps.leanRunSequence : String → SequenceWire.Payload)
#guard !(rejected (SequenceWire.validate
  (greetingSteps.leanRunSequence "<b>& 世界")))
```
