module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Typed HTML author fixture" =>

```leanRun (entry := card)
public noncomputable def card (name : String) : Verso.Output.Html :=
  Classical.choice (show Nonempty Verso.Output.Html from ⟨.text true name⟩)
```
