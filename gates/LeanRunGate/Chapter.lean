module
public import VersoLeanRun
import LeanRunGate.Helper

open Verso Genre Manual InlineLean VersoLeanRun

set_option compiler.postponeCompile false

#doc (Manual) "Run compiled Lean" =>

Change an input and run the declaration compiled from the highlighted source.
Each form owns a separate worker. Stop terminates that worker; the next Run creates a fresh runtime.

# Greeting

```leanRun (entry := LeanRunGate.greet)
@[vir_export]
public def LeanRunGate.greet (name : String) : String :=
  "Hello, " ++ name
```

# Exact natural numbers

```leanRun (entry := LeanRunGate.double)
@[vir_export]
public def LeanRunGate.double (n : Nat) : Nat :=
  LeanRunGate.Helper.twice n
```

## Another independent greeting

```leanRun (entry := LeanRunGate.greet)
#check LeanRunGate.greet
```

# Ordinary Lean

```lean
#check Nat.add
```

# Interruption fixture

This bounded-interface fixture deliberately performs work proportional to its input.
Try a small number, or use a very large number and press Stop.

```leanRun (entry := LeanRunGate.spin)
public def LeanRunGate.spinLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunGate.spinLoop n (acc + 1)

@[vir_export]
public def LeanRunGate.spin (n : Nat) : Nat :=
  LeanRunGate.spinLoop n 0
```
