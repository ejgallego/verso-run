module
public import Vir.Resources.Assets

public def LeanRunBlog.pageResources : Vir.Resources.Bundle :=
  (include_vir_assets (modules := #[LeanRunBlog.Page])).programs[0]!
