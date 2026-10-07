module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Noncomputable scalar entry" =>

```leanRun (entry := chosen)
public noncomputable def chosen (n : Nat) : Nat :=
  Classical.choice (show Nonempty Nat from ⟨n⟩)
```
