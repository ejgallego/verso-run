module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Dependent state" =>
```leanRun (entry := model)
public def model (seed : Nat) : Automaton (Fin (seed + 1)) :=
  { initial := ⟨0, Nat.zero_lt_succ seed⟩, step := id }
```
