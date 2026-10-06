module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Typed HTML author fixture" =>

```leanRun (entry := card)
public def card (name : String) : Verso.Output.Html := .text true name
public def card.leanRunHtml (name : String) : String := name
```
