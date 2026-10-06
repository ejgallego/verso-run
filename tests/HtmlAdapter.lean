module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Typed HTML author fixture" =>

```leanRun (entry := card)
public def card (name : String) : Verso.Output.Html := .text true name
```

```leanRun (entry := card) (output := "html")
#check card
```

#check (card.leanRunHtml : String → String)
#guard card.leanRunHtml "<b>&" == "&lt;b&gt;&amp;"

```leanRun (entry := markup) (output := "html")
@[vir_export] public def markup (text : String) : String := text
```
