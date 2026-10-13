module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
public structure Hidden where
  value : Nat
#doc (Manual) "Missing default display" =>
```leanRun (entry := model)
public def model (seed : Nat) : Automaton Hidden :=
  { initial := ⟨seed⟩, step := id }
```
