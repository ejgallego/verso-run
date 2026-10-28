module
public import Vir.Resources.Assets

public def VersoRunGuide.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[VersoRunGuide.Authoring])
