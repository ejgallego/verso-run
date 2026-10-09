import VersoLeanRun.Model

open Lean VersoLeanRun

-- This is the metadata boundary shared by all three native genre collectors.
#eval show IO Unit from do
  for form in #[FormKind.string, .multilineString, .nat, .bool, .uint64, .html, .multilineHtml] do
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
