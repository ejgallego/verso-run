module
public import Vir.Resources.Assets

public def LeanRunSlides.resources : Vir.Resources.Bundle :=
  (include_vir_assets (modules := #[LeanRunSlides.Deck])).programs[0]!
