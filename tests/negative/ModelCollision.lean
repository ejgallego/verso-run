module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
public def tests.negative.ModelCollision.model.leanRun (seed : Nat) : Nat := seed
#doc (Manual) "Reserved model adapter" =>
```leanRun (entry := model)
public def model (seed : Nat) : Automaton Nat :=
  { initial := seed, step := Nat.succ }
```
