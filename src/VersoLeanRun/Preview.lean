/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public section

namespace VersoLeanRun.Preview

/-- One document policy for Html results and pre-rendered sequence frames. -/
def document (markup : String) : String :=
  "<!doctype html><html><head><meta charset=\"utf-8\">" ++
  "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data:\">" ++
  "<style>body{margin:0;font:16px system-ui,sans-serif;color:#1e2936;overflow-wrap:anywhere}</style>" ++
  "</head><body>" ++ markup ++ "</body></html>"

end VersoLeanRun.Preview
