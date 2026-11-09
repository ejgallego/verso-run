import Lean.Data.Json
import Vir.Resources.Runtime
import Vir.Resources.Validate

def main : IO Unit := do
  let bundle := Vir.Resources.Runtime.bundle
  unless bundle.descriptor.compatibility.leanRevision == Lean.githash do
    throw <| IO.userError "The infoview runtime does not match the selected Lean compiler"
  let some path := bundle.entryPath? "wasm"
    | throw <| IO.userError "The selected runtime has no Wasm role"
  let some wasm := bundle.file? path
    | throw <| IO.userError "The selected runtime has no Wasm payload"
  IO.FS.createDirAll ".vir"
  IO.FS.writeBinFile ".vir/infoview.wasm" wasm.bytes
  let descriptor ← IO.ofExcept <| Lean.Json.parse
    (String.fromUTF8! (Vir.Resources.encodeDescriptor bundle.descriptor))
  IO.FS.writeFile ".vir/infoview-runtime.json" (Lean.Json.mkObj [
    ("contentId", .str bundle.contentId), ("descriptor", descriptor)]).compress
  IO.println s!"Prepared rc2 infoview runtime {bundle.contentId}"
