module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative multiline Nat fixture" =>

```leanRun (entry := multilineNatValue) +multiline
public def multilineNatValue (value : Nat) : Nat := value
```
