module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Entry-selected registration" =>

```leanRun (entry := registeredValue)
public def registeredValue (n : Nat) : Nat := n
```
