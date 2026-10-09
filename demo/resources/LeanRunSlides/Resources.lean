module
public import Vir.Resources.Assets

public def LeanRunSlides.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[LeanRunSlides.Deck])
