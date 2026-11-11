import Vir.Resources.Build
import Vir.Resources.Pack

-- Inspect an existing qualified bundle for a byte-route smoke test. This does
-- not select or overwrite VIR's default runtime carrier or its acquisition lock.
def main (args : List String) : IO Unit := do
  let [compatibility, pack, expectedId, output] := args
    | throw <| IO.userError "usage: CastRuntime COMPATIBILITY PACK EXPECTED_CONTENT_ID OUTPUT"
  let profile ← Vir.Resources.Build.compatibility compatibility
  let bytes ← IO.FS.readBinFile pack
  let bundle ← IO.ofExcept <| (Vir.Resources.Pack.decode bytes).mapError reprStr
  unless bundle.contentId == expectedId && bundle.descriptor.compatibility == profile do
    throw <| IO.userError "The candidate pack does not match the independently selected identity/profile"
  let some path := bundle.entryPath? "wasm"
    | throw <| IO.userError "Missing Wasm role"
  let some wasm := bundle.file? path
    | throw <| IO.userError "Missing Wasm payload"
  let descriptor ← IO.ofExcept <| Lean.Json.parse
    (String.fromUTF8! (Vir.Resources.encodeDescriptor bundle.descriptor))
  IO.FS.createDirAll output
  IO.FS.writeBinFile (System.FilePath.mk output / "runtime.wasm") wasm.bytes
  IO.FS.writeFile (System.FilePath.mk output / "envelope.json") (Lean.Json.mkObj [
    ("contentId", .str bundle.contentId), ("descriptor", descriptor)]).compress
  IO.println s!"Verified source-paired byte smoke input {bundle.contentId}"
