module
public import VersoLeanRun.Views
public meta import Vir.Attributes
public section
open VersoLeanRun
namespace ClientFixture

def machine (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }

@[vir_export]
def trace (seed : UInt64) : SequenceView :=
  ((machine seed).trace 3).view

@[vir_export]
def start (seed : UInt64) : Lean.Vir.RuntimeM AutomatonSession :=
  (machine seed).view

@[vir_export]
def render (frame : Frame) : String := frame.content.asString

end ClientFixture
