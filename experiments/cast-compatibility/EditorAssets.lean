/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
import Lean.Data.Json
import Vir.Resources.Runtime

def main : IO Unit := do
  let bundle := Vir.Resources.Runtime.bundle
  let some wasmPath := bundle.entryPath? "wasm"
    | throw <| IO.userError "Locked VIR runtime has no wasm role"
  let some wasm := bundle.file? wasmPath
    | throw <| IO.userError "Locked VIR runtime has no wasm payload"
  unless bundle.descriptor.compatibility.leanRevision == Lean.githash do
    throw <| IO.userError "Locked runtime does not match this Lean compiler"
  IO.FS.createDirAll ".vir"
  IO.FS.writeBinFile ".vir/runtime.wasm" wasm.bytes
  IO.FS.writeFile ".vir/runtime.json" (Lean.Json.mkObj [
    ("contentId", .str bundle.contentId),
    ("leanRevision", .str bundle.descriptor.compatibility.leanRevision)]).compress
  IO.println s!"Prepared locked runtime {bundle.contentId}"
