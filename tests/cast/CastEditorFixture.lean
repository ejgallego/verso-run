/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import LeanRunInfoview.Setup
public import LeanRunInfoview.Helper
public meta import LeanRunInfoview.Setup

set_option compiler.postponeCompile false
open Verso Genre Manual VersoLeanRun

show_panel_widgets [local VersoLeanRun.Cast.widget with LeanRunInfoview.widgetProps]

#doc (Manual) "Run Lean in the infoview" =>

The examples below run in independent workers. Change a function, wait for the
page to finish checking, and choose Run again. Editing stops the old workers.

Inline math: $`a + x \alpha`.

Display math: $$`\frac{a}{b}`.

```leanRun (entry := greet) (input := "Ada")
public def greet (name : String) : String := "Hello, " ++ name ++ "!"
```

This second example displays an imported source anchor.

```leanRunAnchor double (project := ".") (module := LeanRunInfoview.Helper) (entry := LeanRunInfoview.double) (input := "21")
public def LeanRunInfoview.double (n : Nat) : Nat := n + n
```

Each placement keeps its own input and Stop button.

```leanRun (entry := greet) (input := "Grace")
```

The counter deliberately takes a long time for its initial input. Choose Stop
while it is running; the other controls and the editor remain responsive.

```leanRun (entry := count) (input := "1000000000")
public def count (limit : Nat) : Nat := Id.run do
  let mut total := 0
  for i in [:limit] do
    total := total + i
  return total
```
