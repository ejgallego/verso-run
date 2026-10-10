import VersoLeanRun.Publication
import LeanRunGate.Chapter
import Vir.Compiler.Interface.Classify.Signature
import Lean.Elab.Command

open Lean VersoLeanRun

-- This is the metadata boundary shared by all three native genre collectors.
#eval show IO Unit from do
  let mut wire := #[]
  for input in #[InputKind.string .line, .string .multiline, .nat, .bool, .uint64] do
    for presentation in #[PresentationKind.text, .html, .sequence, .automaton] do
      let form : FormKind := { input, presentation }
      let decoded ← IO.ofExcept (fromJson? (toJson form) : Except String FormKind)
      unless decoded == form do throw <| IO.userError s!"form round-trip failed: {repr form}"
      let expected ← IO.ofExcept form.expectedExport
      wire := wire.push <| Json.mkObj [("form", toJson form), ("expectedExport", expected)]
  for json in #[Json.str "natSvg", Json.str "multilineBool",
      Json.mkObj [("nat", Json.mkObj [("multiline", Json.bool true)])]] do
    match (fromJson? json : Except String FormKind) with
    | .error _ => pure ()
    | .ok form => throw <| IO.userError s!"unsupported combination decoded as {repr form}"
  let stale := Json.mkObj [("program", .str "Test"), ("declaration", .str "Test.echo"),
    ("shape", .str "string"), ("output", .str "html"), ("multiline", .bool false),
    ("initialInput", .str ""), ("collapsed", .bool false), ("signature", .str "{}"),
    ("sourceLine", toJson (1 : Nat)), ("sourceColumn", toJson (0 : Nat)),
    ("producerModule", .str "Test"), ("callable", .str "Test.echo")]
  match (fromJson? stale : Except String Experiment) with
  | .error _ => pure ()
  | .ok _ => throw <| IO.userError "obsolete metadata without a typed form decoded"
  IO.println s!"FORM_WIRE {Json.compress (toJson wire)}"
  IO.println "typed form round-trips and unsupported metadata rejection passed"

namespace ContractFixtures
def text (input : String) : String := input
def natural (input : Nat) : Nat := input
def boolean (input : Bool) : Bool := input
def unsigned (input : UInt64) : UInt64 := input
def sequence (input : String) : SequenceWire.Payload :=
  { version := 1, frames := #[{ label := input, html := "", error := none }] }
def booleanHtml (input : Bool) : String := toString input
def unsignedHtml (input : UInt64) : String := toString input
def naturalSequence (input : Nat) : SequenceWire.Payload := { version := input, frames := #[] }
def booleanSequence (input : Bool) : SequenceWire.Payload := { version := if input then 1 else 0, frames := #[] }
def unsignedSequence (input : UInt64) : SequenceWire.Payload := { version := input.toNat, frames := #[] }
def live (input : String) : Lean.Vir.RuntimeM AutomatonWire.Session :=
  (AutomatonView.error input).start
def naturalLive (input : Nat) : Lean.Vir.RuntimeM AutomatonWire.Session := live (toString input)
def booleanLive (input : Bool) : Lean.Vir.RuntimeM AutomatonWire.Session := live (toString input)
def unsignedLive (input : UInt64) : Lean.Vir.RuntimeM AutomatonWire.Session := live (toString input)
end ContractFixtures

-- Every admitted input/presentation pair matches independent compiler classification.
run_cmd Lean.Elab.Command.liftTermElabM do
  let cases : Array (Name × FormKind) := #[
    (`ContractFixtures.text, ⟨.string .line, .text⟩),
    (`ContractFixtures.text, ⟨.string .multiline, .text⟩),
    (`LeanRunGate.htmlGreeting.leanRunHtml, ⟨.string .line, .html⟩),
    (`LeanRunGate.htmlGreeting.leanRunHtml, ⟨.string .multiline, .html⟩),
    (`ContractFixtures.sequence, ⟨.string .line, .sequence⟩),
    (`ContractFixtures.sequence, ⟨.string .multiline, .sequence⟩),
    (`ContractFixtures.natural, ⟨.nat, .text⟩),
    (`ContractFixtures.boolean, ⟨.bool, .text⟩),
    (`ContractFixtures.unsigned, ⟨.uint64, .text⟩),
    (`LeanRunGate.diagram.leanRunHtml, ⟨.nat, .html⟩),
    (`ContractFixtures.booleanHtml, ⟨.bool, .html⟩),
    (`ContractFixtures.unsignedHtml, ⟨.uint64, .html⟩),
    (`ContractFixtures.naturalSequence, ⟨.nat, .sequence⟩),
    (`ContractFixtures.booleanSequence, ⟨.bool, .sequence⟩),
    (`ContractFixtures.unsignedSequence, ⟨.uint64, .sequence⟩),
    (`ContractFixtures.live, ⟨.string .line, .automaton⟩),
    (`ContractFixtures.live, ⟨.string .multiline, .automaton⟩),
    (`ContractFixtures.naturalLive, ⟨.nat, .automaton⟩),
    (`ContractFixtures.booleanLive, ⟨.bool, .automaton⟩),
    (`ContractFixtures.unsignedLive, ⟨.uint64, .automaton⟩)]
  for (name, form) in cases do
    let info ← Lean.getConstInfo name
    let .ok signature ← Vir.Interface.analyzeExportInterface info.type
      | throwError "classification failed for {name}"
    let .ok classified := Lean.Json.parse signature.toExpectedSignatureJson
      | throwError "invalid compiler expectation for {name}"
    let .ok normalized := form.expectedExport
      | throwError "invalid form expectation for {name}"
    unless classified == normalized do
      throwError "normalized expectation differs from VIR classification for {name}"
