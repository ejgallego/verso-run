module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

public abbrev LiveView := AutomatonView

#doc (Manual) "Typed live models" =>

```leanRun (entry := counter) (input := "9007199254740993")
public def counter (seed : Nat) : LiveView :=
  let machine : Automaton Nat := { initial := seed, step := (· + 1) }
  machine.view fun n => .text true (toString n)
```

```leanRun (entry := toggle) (input := "true")
public def toggle (seed : Bool) : AutomatonView :=
  let machine : Automaton Bool := { initial := seed, step := Bool.not }
  machine.view fun b => .text true (toString b)
```

```leanRun (entry := word) (input := "18446744073709551615")
public def word (seed : UInt64) : AutomatonView :=
  let machine : Automaton UInt64 := { initial := seed, step := (· + 1) }
  machine.view fun n => .text true (toString n)
```

```leanRun (entry := toggle)
#check (toggle.leanRunAutomaton : Bool → Lean.Vir.RuntimeM AutomatonWire.Session)
```
