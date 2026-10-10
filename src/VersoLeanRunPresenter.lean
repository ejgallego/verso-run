/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Sequence
public import VersoLeanRun.Preview
public import Vir.Browser
public meta import Vir.Attributes
public section

namespace VersoLeanRun.Presenter
open Lean.Vir Lean.Vir.Browser Verso.Output Verso.Output.Html

private def failure {α : Type} (message : String) : DomM α := by
  unfold DomM RuntimeM
  exact throw (IO.userError message)

private def text (element : Js Element) (value : String) : DomM Unit := do
  Element.setTextContent element (← Js.Nullable.ofJs (← JsValue.ofString value))

private def attr (element : Js Element) (name value : String) : DomM Unit := do
  Element.setAttribute element (← JsValue.ofString name) (← JsValue.ofString value)

/-- Html and sequence frames share one compiled sandbox-document policy. -/
@[vir_export]
def mountHtml (frame : Js Element) (markup : String) : DomM Unit :=
  attr frame "srcdoc" (Preview.document markup)

private def child (root : Js Element) (selector : String) : DomM (Js Element) := do
  let found ← Element.querySelector root (← JsValue.ofString selector)
  let some element ← Js.Nullable.toOption found
    | failure s!"Missing sequence control: {selector}"
  return element

-- Explicit bodies keep empty non-void tags closed in the pinned Html serializer.
private def controls (frames : Array SequenceWire.Frame) : Html := Id.run do
  let labels := Html.fromArray <| frames.mapIdx fun i frame =>
    {{ <button type="button" class="lean-run-sequence-step" data-step={{toString i}}>{{frame.label}}</button> }}
  return {{ <div class="lean-run-sequence-controls">
    <div class="lean-run-sequence-strip" aria-label="Sequence steps">{{labels}}</div>
    <div class="lean-run-sequence-navigation">
      <button type="button" class="lean-run-sequence-prev" aria-label="Previous step"> "Previous" </button>
      <label> "Step" <input type="range" class="lean-run-sequence-range" min="0" max={{toString (frames.size - 1)}} value="0"/> </label>
      <button type="button" class="lean-run-sequence-next" aria-label="Next step"> "Next" </button>
    </div>
    <p class="lean-run-sequence-position" role="status" aria-live="polite"> " " </p>
    <p class="lean-run-sequence-error" role="alert"> " " </p>
    <iframe class="lean-run-sequence-frame" title="Sequence state" sandbox="" referrerpolicy="no-referrer"> " " </iframe>
  </div> }}

/-- Live controls persist while each new Lean frame replaces the previous one.
The asynchronous worker bridge owns Play/Pause scheduling and backpressure. -/
@[vir_export]
def showAutomaton (root : Js Element) (frame : SequenceWire.Frame) : DomM Unit := do
  let controls ← Element.querySelector root (← JsValue.ofString ".lean-run-automaton-controls")
  if (← Js.Nullable.toOption controls).isNone then
    let markup := {{ <div class="lean-run-automaton-controls">
      <div class="lean-run-sequence-navigation">
        <button type="button" class="lean-run-play"> "Play" </button>
        <button type="button" class="lean-run-step"> "Step" </button>
      </div>
      <p class="lean-run-sequence-position" role="status"> " " </p>
      <p class="lean-run-sequence-error" role="alert"> " " </p>
      <iframe class="lean-run-sequence-frame" title="Automaton state" sandbox="" referrerpolicy="no-referrer"> " " </iframe>
    </div> }}
    Element.setInnerHTML root (← JsValue.ofString markup.asString)
  text (← child root ".lean-run-sequence-position") frame.label
  text (← child root ".lean-run-sequence-error") (frame.error.getD "")
  attr (← child root ".lean-run-sequence-frame") "srcdoc" (Preview.document frame.html)

/-- The bounded presenter runs in the browser; computation stays in the worker.
The returned callback removes listeners before the host disposes its runtime. -/
@[vir_export]
def mount (root : Js Element) (data : SequenceWire.Payload) : DomM (Js.Function0 Unit) := do
  let payload ← match SequenceWire.validate data with
    | .ok payload => pure payload
    | .error message => failure message
  Element.setInnerHTML root (← JsValue.ofString (controls payload.frames).asString)
  let previous ← child root ".lean-run-sequence-prev"
  let next ← child root ".lean-run-sequence-next"
  let range ← child root ".lean-run-sequence-range"
  let position ← child root ".lean-run-sequence-position"
  let error ← child root ".lean-run-sequence-error"
  let preview ← child root ".lean-run-sequence-frame"
  let buttons ← payload.frames.mapIdxM fun i _ => child root s!"[data-step='{i}']"
  let selected ← RuntimeRef.new (none : Option Nat)
  let alive ← RuntimeRef.new true
  let display : Nat → DomM Unit := fun (index : Nat) => do
    if !(← alive.get) then return
    let index := index.min (payload.frames.size - 1)
    if (← selected.get) == some index then return
    selected.set (some index)
    let frame := payload.frames[index]!
    text position s!"Step {index + 1} of {payload.frames.size}: {frame.label}"
    text error (frame.error.getD "")
    attr preview "srcdoc" (Preview.document frame.html)
    attr previous "aria-disabled" (if index == 0 then "true" else "false")
    attr next "aria-disabled" (if index + 1 == payload.frames.size then "true" else "false")
    if let some input ← HTMLInputElement.fromElement range then
      HTMLInputElement.setValue input (← JsValue.ofString (toString index))
    for (button, i) in buttons.zipIdx do
      attr button "aria-pressed" (if i == index then "true" else "false")
  let click ← JsValue.ofString "click"
  let input ← JsValue.ofString "input"
  let mut listeners : Array (Js Element × Js String × Js EventListener) := #[]
  for (button, move) in [(previous, false), (next, true)] do
    let listener ← EventListener.ofLean fun _ => do
      let index := (← selected.get).getD 0
      display (if move then index + 1 else index - 1)
    Element.addEventListener button click listener
    listeners := listeners.push (button, click, listener)
  for (button, i) in buttons.zipIdx do
    let listener ← EventListener.ofLean fun _ => display i
    Element.addEventListener button click listener
    listeners := listeners.push (button, click, listener)
  let scrub ← EventListener.ofLean fun event => do
    if let some value ← Js.Nullable.toOption (← Event.formValueNullable event) then
      if let some index := (← JsValue.toString value).toNat? then display index
  Element.addEventListener range input scrub
  listeners := listeners.push (range, input, scrub)
  display 0
  Js.Function.ofLean0Void <| DomM.toRuntime do
    alive.set false
    for (element, event, listener) in listeners do
      Element.removeEventListener element event listener

end VersoLeanRun.Presenter
