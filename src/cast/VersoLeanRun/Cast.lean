/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoCast.Manual.Preview
public import VersoLeanRun.Manual
public import Vir.Infoview.Widget
public import Vir.Resources.Validate
public meta import VersoLeanRun.Cast.Server
public meta import Vir.Infoview.Widget
meta import all VersoCast.Manual.Preview
meta import all VersoCast.Manual
meta import all VersoCast.Highlighting
meta import all VersoCast.Renderer
meta import all VersoCast.Renderer.Table
meta import all VersoLeanRun.Render
meta import all VersoLeanRun.Model
meta import Vir.Attributes

set_option compiler.postponeCompile false

public section
namespace VersoLeanRun.Cast
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def nativeComponent (value : Js.Any) : FunctionComponent Props := by
  unfold FunctionComponent Js.Function1 Js.Any Js at *
  exact value

private def create (placement : FunctionComponent Props) : RuntimeM VersoCast.Manual.Preview.Bridge :=
  VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let manual ← VersoCast.Manual.createRenderers styles
      pure fun page matchesSelection => { manual with
        renderBlock? := fun key attributes block children => do
          if block.name != `VersoLeanRun.Block.leanRun then
            return ← manual.renderBlock? key attributes block children
          let .ok (entry : Experiment) := Lean.fromJson? block.data | return none
          let props ← attributes "lean-run" styles.part
          let provenance ← js%{
            "session" := page.session, "snapshotRef" := page.snapshotRef,
            "uri" := (← JsValue.ofString page.uri),
            "version" := (← JsValue.ofFloat page.version.toFloat),
            "hasErrors" := (← JsValue.ofBool page.hasErrors) }
          let input ← js%{
            "page" := provenance,
            "matchesSelection" := (← JsValue.ofBool matchesSelection),
            "description" := (← JsValue.ofString entry.browserDescription.compress),
            "controlsHtml" := (← JsValue.ofString (renderControls entry).render) }
          return some (← jsx%{<section @props={props}>
            {Js.Array.ofArray (← children.render ())}
            {Node.functionComponent placement input (← Js.Array.empty)}
          </section>}) } }

@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  FunctionComponent.ofLean fun props => do
    let placement := nativeComponent (← Js.Object.get props (← js#"runPlacement"))
    let build ← Js.Function.ofLean0 do
      let bridge ← create placement
      js%{ "decode" := bridge.decode, "view" := bridge.view }
    let bridge ← Hooks.useMemo build (← js#[Js.erase placement])
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let host := nativeComponent (← Js.Object.get props (← js#"pageHost"))
    let input ← js%{ "uri" := uri,
      "decode" := (← Js.Object.get bridge (← js#"decode")),
      "view" := (← Js.Object.get bridge (← js#"view")) }
    Node.functionComponent host input (← Js.Array.empty)

vir_proof_widget View

@[widget_module]
def widget : Lean.Widget.Module where
  javascript := (include_str "../../../.vir-generated/CastWidget.mjs").replace "__VIR_SHELL__"
    ("widget_module:hash," ++ toString Lean.Vir.Infoview.widget.javascriptHash.val)

structure Props where
  wasmPath : String
  irPackage : Infoview.IRPackage
  setupHint : String
  runRuntimeManifest : Lean.Json
  deriving Lean.Server.RpcEncodable

/-- The canonical descriptor codec stays owned by VIR. -/
private def runtimeManifest (bundle : Vir.Resources.Bundle) : Lean.Json :=
  match Lean.Json.parse (String.fromUTF8! (Vir.Resources.encodeDescriptor bundle.descriptor)) with
  | .ok descriptor => Lean.Json.mkObj [
      ("contentId", .str bundle.contentId), ("descriptor", descriptor)]
  | .error error => panic! s!"Invalid canonical runtime descriptor: {error}"

/-- Configure the widget from the consumer's independently selected bundle. -/
def props (bundle : Vir.Resources.Bundle) : Props :=
  { wasmPath := ".vir/infoview.wasm"
    irPackage := irPackage
    setupHint := "Run python3 scripts/setup-cast-demo.py, then reopen the demo or restart its Lean server."
    runRuntimeManifest := runtimeManifest bundle }

end VersoLeanRun.Cast
