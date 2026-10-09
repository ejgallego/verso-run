module
public import Vir.Resources.Assets

public def LeanRunBlog.postResources : Vir.Resources.Bundle :=
  (include_vir_assets (modules := #[LeanRunBlog.Post])).programs[0]!
