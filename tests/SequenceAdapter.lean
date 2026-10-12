module
public import VersoLeanRun
public import LeanRunSequence.Examples
public meta import LeanRunSequence.Examples
public meta import LeanRunGate.Stack
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

def rejected (value : Except String α) : Bool :=
  match value with | .ok _ => false | .error _ => true

def viewWithFrames (count : Nat) : SequenceView :=
  { initial := { label := "Frame", content := .text true "State" }
    steps := Array.replicate count { label := "Frame", content := .text true "State" } }

#guard !rejected (SequenceView.validate (viewWithFrames 127))
#guard rejected (SequenceView.validate (viewWithFrames 128))

-- The initial state is present even for zero transitions. Rendering never calls
-- the transition, and custom labels describe the same iteration indices.
def successors := Sequence.iterate (· + 2) (3 : Nat) 3 (fun i => s!"State {i}")
#guard successors.initial.content == 3
#guard successors.initial.label == "State 0"
#guard successors.steps.map (·.content) == #[5, 7, 9]
#guard successors.steps.map (·.label) == #["State 1", "State 2", "State 3"]
#guard (Sequence.iterate Bool.not true 0).steps.isEmpty
#guard (Sequence.iterate Bool.not true 0).initial.content
#guard (Sequence.iterate Bool.not true 3).steps.map (·.content) == #[false, true, false]
#guard (Sequence.iterate Bool.not true 0 |>.view fun _ => .empty).frames.size == 1
#guard (SequenceView.error "No initial model").frames.size == 1
#guard (SequenceView.error "No initial model").initial.content.asString == ""
#guard (SequenceView.error "No initial model").initial.error == some "No initial model"

def failingBoundary : Automaton Nat := {
  initial := 0
  step := fun n => if n < 3 then n + 1 else panic! "trace evaluated past its boundary" }
#guard (failingBoundary.trace 0).initial.content == 0
#guard (failingBoundary.trace 3).steps.map (·.content) == #[1, 2, 3]

def marked : Sequence Nat := {
  initial := { label := "First", content := 1, error := some "initial note" }
  steps := #[{ label := "Second", content := 2, error := some "step note" }] }
#guard (toString <$> marked).initial.content == "1"
#guard (toString <$> marked).initial.label == marked.initial.label
#guard (toString <$> marked).initial.error == marked.initial.error
#guard ((toString <$> marked).steps[0]?.bind (·.error)) ==
  (marked.steps[0]?.bind (·.error))
#guard (marked.map (· + 1)).steps.map (·.content) == #[3]
#guard ((Sequence.iterate id "<b>&" 0).view).initial.content.asString == "&lt;b&gt;&amp;"

-- Already-rendered values remain HTML; custom renderers need no ToString instance.
def markup : SequenceView := {
  initial := { label := "Markup", content := .text false "<b>Kept</b>" } }
#guard markup.view.initial.content.asString == "<b>Kept</b>"

structure CustomState where
  value : Nat

def customSequence : Sequence CustomState := {
  initial := { label := "Custom", content := ⟨3⟩ } }
#guard (customSequence.view fun state => .text true (toString state.value)).initial.content.asString == "3"
#guard ((fun n => n + 1) <$> (Frame.mk "Label" (2 : Nat) (some "note"))).error == some "note"

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
    initial := { label := "Start", content := name }
    steps := #[{ label := "Greeting", content := "Hello, " ++ name }] }
  sequence.view (Verso.Output.Html.text true)
```

```leanRun (entry := greetingSteps)
#check (greetingSteps : String → SequenceView)
#guard !(rejected (SequenceView.validate
  (greetingSteps "<b>& 世界")))
```
