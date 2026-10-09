module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Typed HTML author fixture" =>

```leanRun (entry := card)
public def card (name : String) : Verso.Output.Html := .text true name
```

```leanRun (entry := card)
#check card
```

#check (card.leanRunHtml : String → String)
#guard card.leanRunHtml "<b>&" == "&lt;b&gt;&amp;"

```leanRun (entry := markup)
public def markup (text : String) : String := text
```

```leanRun (entry := markup) (input := "<b>&")
#check markup
```

-- String results are text; only Html results request a preview.

```leanRun (entry := legacyMarked)
@[vir_export] public def legacyMarked (n : Nat) : Nat := n
```

```leanRun (entry := legacyMarked)
#check legacyMarked
```
