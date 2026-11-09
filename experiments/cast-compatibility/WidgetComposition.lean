/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget

namespace WidgetComposition

def shellSpecifier : String :=
  "widget_module:hash," ++ toString Lean.Vir.Infoview.widget.javascriptHash.val

-- The wrapper receives React and the registered shell through the editor's
-- module mechanism. No private JS path or copy of the VIR loader is involved.
@[widget_module]
def wrapper : Lean.Widget.Module where
  javascript := "import VirShell from '" ++ shellSpecifier ++ "';\n" ++
    "import * as React from 'react';\n" ++
    "function RunComponent() { const [count, setCount] = React.useState(0); return React.createElement('button', { 'data-run-probe': 'true', onClick: () => setCount(n => n + 1) }, String(count)); }\n" ++
    "export default function Preview(props) { return React.createElement(VirShell, { ...props, runComponent: RunComponent }); }\n"

#guard wrapper.javascript.startsWith ("import VirShell from '" ++ shellSpecifier ++ "';")

-- Only this consumer's generated output is written. The runtime is not opened.
#eval do
  let contents := Lean.Json.mkObj [
    ("shellHash", .str (toString Lean.Vir.Infoview.widget.javascriptHash.val)),
    ("wrapperHash", .str (toString wrapper.javascriptHash.val)),
    ("shellSource", .str Lean.Vir.Infoview.widget.javascript),
    ("wrapperSource", .str wrapper.javascript)]
  IO.FS.writeFile "widget-composition.json" contents.compress

end WidgetComposition
