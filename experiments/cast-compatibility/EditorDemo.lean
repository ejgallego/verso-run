/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoManual
public import EditorPreview
public meta import EditorPreview

set_option compiler.postponeCompile false
open Verso Genre Manual
open Verso.Genre.Manual.InlineLean

show_panel_widgets [local EditorPreview.widget with EditorPreview.preparedWidgetProps]

#doc (Manual) "Cast preview smoke test" =>

This is the document-preview prototype for verso-run. Edit this sentence and
wait for Lean to check the page; the infoview should update the preview.

Execution controls are not connected in this smoke test. It uses ordinary Lean
source blocks, not executable Run blocks. The native host aborts preview requests
on edits, processing and server restart. Actual editor behavior still needs
qualification.

```lean
public def greeting (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

The code above is highlighted by Cast's existing Manual adapter. This is a
useful editor check before adding the invocation backend and Run controls.
