import VersoLeanRun.Publication
import Vir.Compiler.Interface.Classify.Signature
import Lean.Elab.Command

open Lean VersoLeanRun

-- This is the metadata boundary shared by all three native genre collectors.
#eval show IO Unit from do
  for form in #[FormKind.string .line .text, .string .multiline .text, .nat, .bool, .uint64,
      .string .line .html, .string .multiline .html,
      .string .line .sequence, .string .multiline .sequence] do
    let decoded ← IO.ofExcept (fromJson? (toJson form) : Except String FormKind)
    unless decoded == form do throw <| IO.userError s!"form round-trip failed: {repr form}"
  for json in #[Json.str "natHtml", Json.str "multilineBool",
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
  IO.println "typed form round-trips and unsupported metadata rejection passed"

namespace ContractFixtures
def text (input : String) : String := input
def natural (input : Nat) : Nat := input
def boolean (input : Bool) : Bool := input
def unsigned (input : UInt64) : UInt64 := input
end ContractFixtures

-- Compare normalization with independent VIR classification, including both HTML
-- presentations whose generated serializer has a String → String type.
run_cmd Lean.Elab.Command.liftTermElabM do
  for (name, form) in #[(`ContractFixtures.text, FormKind.string .line .text),
      (`ContractFixtures.text, .string .multiline .text),
      (`ContractFixtures.text, .string .line .html),
      (`ContractFixtures.text, .string .multiline .html),
      (`ContractFixtures.text, .string .line .sequence),
      (`ContractFixtures.text, .string .multiline .sequence),
      (`ContractFixtures.natural, .nat), (`ContractFixtures.boolean, .bool),
      (`ContractFixtures.unsigned, .uint64)] do
    let info ← Lean.getConstInfo name
    let .ok signature ← Vir.Interface.analyzeExportInterface info.type
      | throwError "classification failed for {name}"
    let .ok classified := Lean.Json.parse signature.toExpectedSignatureJson
      | throwError "invalid compiler expectation for {name}"
    let .ok normalized := form.expectedExport
      | throwError "invalid form expectation for {name}"
    unless classified == normalized do
      throwError "normalized expectation differs from VIR classification for {name}"
