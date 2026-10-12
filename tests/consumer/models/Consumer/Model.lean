module
public import VersoLeanRun.Views
public section

namespace Consumer
open VersoLeanRun

-- The same UInt64 transition used by the document-free client fixture.
def counter (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }

def finite (seed : UInt64) : SequenceView :=
  ((counter seed).trace 3).view

def live (seed : UInt64) : AutomatonView :=
  (counter seed).view

def increment (seed : UInt64) : UInt64 := seed + 1

end Consumer
