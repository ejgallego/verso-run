module
public import VersoLeanRun

open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "My runnable manual" =>

Change a name and choose Run. Both examples execute the displayed Lean function.

# Greeting

```leanRun (entry := Starter.greet) (input := "Ada")
@[vir_export]
public def Starter.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

# HTML card

This function returns typed HTML. Verso escapes the name when rendering it.

```leanRun (entry := Starter.card) (input := "Ada")
open Verso.Output.Html

public def Starter.card (name : String) :
    Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff">
    <h2> "Hello, " {{name}} "!" </h2>
  </section> }}
```
