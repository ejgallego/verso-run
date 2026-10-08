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

/-- Shared console markup around source already rendered by its native genre. -/
def renderConsole (experiment : Experiment) (source : Array Html) (instanceId : String)
    (rendererUrl : Option String := none) : Html := Id.run do
  let source := Html.fromArray source
  let label := if experiment.shape == "nat" then "Natural number" else "Text"
  let initial := experiment.initialInput
  let placeholder := if experiment.shape == "nat" then "0" else "Enter text"
  let sourcePanel := if experiment.collapsed then
    {{ <details class="lean-run-source"><summary> "View Lean implementation" </summary> {{source}} </details> }}
    else {{ <div class="lean-run-source"> {{source}} </div> }}
  let preview := if experiment.output == "html" then
    {{ <iframe class="lean-run-preview" title="HTML result" sandbox="" referrerpolicy="no-referrer" hidden="hidden"/> }}
    else .empty
  let console := {{ <section class="lean-run" data-experiment={{(toJson experiment).compress}} data-instance={{instanceId}}>
    {{sourcePanel}}
    <div class="lean-run-console">
      <form>
        <label> {{label}} <input type="text" value={{initial}} placeholder={{placeholder}} maxlength="4096" autocomplete="off"/> </label>
        <button type="submit" disabled="disabled"> "Run" </button>
        <button type="button" class="lean-run-stop" disabled="disabled"> "Stop" </button>
      </form>
      <p class="lean-run-status" role="status" aria-live="polite"> "Ready" </p>
      <pre class="lean-run-output" aria-label="Result"/>
      {{preview}}
      <noscript> "Enable JavaScript to run this compiled Lean example." </noscript>
    </div>
  </section> }}
  return match rendererUrl, console with
    | some url, .tag tagName attrs contents =>
      .tag tagName (attrs.push ("data-lean-run-renderer", url)) contents
    | _, _ => console

end VersoLeanRun
