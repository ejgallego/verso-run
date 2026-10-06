module
public import VersoLeanRun
import LeanRunGate.Helper

open Verso Genre Manual InlineLean VersoLeanRun

set_option compiler.postponeCompile false

#doc (Manual) "Run compiled Lean" =>

Try the Lean functions shown below. Change an input, then choose Run to see the result.
Use Stop to interrupt a calculation.

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

# Try Stop

This function counts up to the number you enter. Try a small number first.
Then enter `1000000000000`, choose Run, and press Stop to interrupt it.

```leanRun (entry := LeanRunGate.spin)
public def LeanRunGate.spinLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunGate.spinLoop n (acc + 1)

@[vir_export]
public def LeanRunGate.spin (n : Nat) : Nat :=
  LeanRunGate.spinLoop n 0
```
