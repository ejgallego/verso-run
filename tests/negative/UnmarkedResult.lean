module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Unregistered result type" =>

```leanRun (entry := packet)
public structure Packet where
  value : Nat
public def packet (input : Nat) : Packet := ⟨input⟩
```
