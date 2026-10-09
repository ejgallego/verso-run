/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Verso.Output.Html
public section
open Lean Verso.Output Verso.Output.Html
namespace VersoLeanRun

/-- Shared input, state, output, and preview controls. -/
def renderControls (experiment : Experiment) : Html := Id.run do
  let label := match experiment.form.scalar with
    | .nat => "Natural number"
    | .uint64 => "Unsigned 64-bit integer"
    | .bool => "Boolean"
    | .string => "Text"
  let initial := experiment.initialInput
  let placeholder := if experiment.form.scalar == .nat || experiment.form.scalar == .uint64 then "0" else "Enter text"
  let control := if experiment.form.scalar == .bool then
    let options := if initial == "true" then
      {{ <option value="false"> "false" </option><option value="true" selected="selected"> "true" </option> }}
      else {{ <option value="false" selected="selected"> "false" </option><option value="true"> "true" </option> }}
    {{ <select>{{options}}</select> }}
    else if experiment.form.multiline then
      -- HTML removes the first leading LF in textarea contents. Preserve the preset.
      {{ <textarea rows="4" maxlength="4096" placeholder={{placeholder}}>{{"\n" ++ initial}}</textarea> }}
    else {{ <input type="text" value={{initial}} placeholder={{placeholder}} maxlength="4096" autocomplete="off"/> }}
  let preview := if experiment.form.isHtml then
    {{ <iframe class="lean-run-preview" title="HTML result" sandbox="" referrerpolicy="no-referrer" hidden="hidden"/> }}
    else if experiment.form.isSequence then
      {{ <div class="lean-run-sequence" hidden="hidden"/> }}
    else .empty
  return {{ <div class="lean-run-console">
      <form>
        <label> {{label}} {{control}} </label>
        <button type="submit" disabled="disabled"> "Run" </button>
        <button type="button" class="lean-run-stop" disabled="disabled"> "Stop" </button>
      </form>
      <p class="lean-run-status" role="status" aria-live="polite"> "Ready" </p>
      <pre class="lean-run-output" aria-label="Result"/>
      {{preview}}
      <noscript> "Enable JavaScript to run this compiled Lean example." </noscript>
    </div> }}

/-- Shared console markup around source already rendered by its native genre. -/
def renderConsole (experiment : Experiment) (source : Array Html) (instanceId : String)
    (rendererUrl : Option String := none) : Html := Id.run do
  let source := Html.fromArray source
  let sourcePanel := if experiment.collapsed then
    {{ <details class="lean-run-source"><summary> "View Lean implementation" </summary> {{source}} </details> }}
    else {{ <div class="lean-run-source"> {{source}} </div> }}
  let console := {{ <section class="lean-run" data-experiment={{(toJson experiment).compress}} data-instance={{instanceId}}>
    {{sourcePanel}}
    {{renderControls experiment}}
  </section> }}
  return match rendererUrl, console with
    | some url, .tag tagName attrs contents =>
      .tag tagName (attrs.push ("data-lean-run-renderer", url)) contents
    | _, _ => console

end VersoLeanRun
