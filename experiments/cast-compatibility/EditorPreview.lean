/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoCast.Manual.Preview
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
meta import all VersoCast.Manual.Preview
meta import all VersoCast.Manual
meta import all VersoCast.Highlighting
meta import all VersoCast.Renderer
meta import all VersoCast.Renderer.Table
meta import Vir.Attributes

set_option compiler.postponeCompile false

public section
namespace EditorPreview
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js

-- Read-only smoke host. It intentionally does not claim the production
-- cursor-independent session/reprocessing mapping required for Run execution.
@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  let preview ← VersoCast.Manual.Preview.create
  let generation ← JsValue.ofFloat 0
  FunctionComponent.ofLean fun props => do
    let session ← Infoview.useRpcSession
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let calculate ← Js.Function.ofLean0 do
      let input ← Props.WithData.make (← LeanRef.toJSL
        ({ session, uri, generation := Js.erase generation } : VersoCast.Manual.Preview.Input))
      Node.functionComponent preview input (← Js.Array.empty)
    Hooks.useMemo calculate (← js#[Js.erase session, Js.erase uri])

vir_proof_widget View

def preparedWidgetProps : Infoview.WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run the compatibility driver's --editor step, then reopen this file or restart its Lean server." }

end EditorPreview
