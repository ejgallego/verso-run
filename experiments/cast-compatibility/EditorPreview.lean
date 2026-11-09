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

-- Supplied by the registered native wrapper below. Preserve its identity.
private def pageHost (value : Js.Any) : FunctionComponent Props := by
  unfold FunctionComponent Js.Function1 Js.Any Js at *
  exact value

-- Native React owns the selection, request and cleanup. The Lean factory only
-- decodes and renders; it does not retarget controls through a global callback.
@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  let bridge ← VersoCast.Manual.Preview.create
  FunctionComponent.ofLean fun props => do
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let host := pageHost (← Js.Object.get props (← js#"pageHost"))
    let input ← js%{ "uri" := uri, "decode" := bridge.decode, "view" := bridge.view }
    Node.functionComponent host input (← Js.Array.empty)

vir_proof_widget View

@[widget_module]
def widget : Lean.Widget.Module where
  javascript := (include_str "EditorHostBundle.mjs").replace "__VIR_SHELL__"
    ("widget_module:hash," ++ toString Lean.Vir.Infoview.widget.javascriptHash.val)

def preparedWidgetProps : Infoview.WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run the compatibility driver's --editor step, then reopen this file or restart its Lean server." }

end EditorPreview
