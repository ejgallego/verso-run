module
import VersoLeanRunPresenter
import ClientResources
meta import Lean.Elab.Command

-- Check ordinary imports separately from the meta imports used to register and
-- classify exports. The native carrier must not import the DOM implementation.
open Lean in
private meta partial def ordinaryClosure (env : Environment) (name : Name)
    (visited : Array Name := #[]) : Array Name := Id.run do
  if visited.contains name then return visited
  let mut visited := visited.push name
  if let some index := env.getModuleIdx? name then
    for imported in env.header.moduleData[index.toNat]!.imports do
      if !imported.isMeta then visited := ordinaryClosure env imported.module visited
  return visited

run_cmd do
  let env ← Lean.getEnv
  for (root, forbidden) in #[
      (`VersoLeanRunPresenter, #[`VersoManual, `VersoBlog, `VersoSlides,
        `VersoLeanRun.Callable, `VersoLeanRun.Publication]),
      (`ClientResources, #[`Vir.Browser, `VersoLeanRunPresenter,
        `VersoManual, `VersoBlog, `VersoSlides, `Vir.Compiler])] do
    for imported in ordinaryClosure env root do
      for forbiddenPrefix in forbidden do
        if forbiddenPrefix.isPrefixOf imported then
          throwError "{root} ordinarily imports forbidden machinery: {imported}"
