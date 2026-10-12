module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

public abbrev LiveView := AutomatonView

#doc (Manual) "Typed live models" =>

```leanRun (entry := counter) (input := "9007199254740993")
public def counter (seed : Nat) : Automaton Nat :=
  { initial := seed, step := (· + 1) }
```

```leanRun (entry := toggle) (input := "true")
public def toggle (seed : Bool) : Automaton Bool :=
  { initial := seed, step := Bool.not }
```

```leanRun (entry := word) (input := "18446744073709551615")
public def word (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }
```

```leanRun (entry := toggle)
#check (toggle : Bool → Automaton Bool)
#check (tests.AutomatonAdapter.toggle.leanRun : Bool → LiveView)
```
