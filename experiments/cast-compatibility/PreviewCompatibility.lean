/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import Compatibility
public import VersoCast.Manual.Preview
public meta import VersoCast.Manual.Preview.Server

public section
namespace PreviewCompatibility
open Lean.Vir Lean.Vir.React

-- Build only the decoder/view bridge. Native React owns request lifetimes.
def create : RuntimeM VersoCast.Manual.Preview.Bridge :=
  VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let handlers ← VersoCast.Manual.createRenderers styles
      pure fun _page _matchesSelection => handlers }

-- Keep the captured session and reference as native values, not document JSON.
def owningSession (page : VersoCast.Manual.Preview.PageInfo) : Js Infoview.RpcSession :=
  page.session

def nativeReference (page : VersoCast.Manual.Preview.PageInfo) : Js.Any :=
  page.snapshotRef

meta section
open Lean Server VersoCast.Manual.Preview.Server

structure InspectParams where
  snapshotRef : WithRpcRef Page
  deriving RpcEncodable

-- Compile a consumer-side handler against the public admission/version API.
-- This gate does not invoke the RPC or establish freshness in a real editor.
@[server_rpc_method]
def inspect (params : InspectParams) : RequestM (RequestTask String) :=
  RequestM.asTask do
    let page := params.snapshotRef.val
    requireErrorFree page
    let encoded := (toJson page.document).compress
    requireMatchingVersion page
    pure encoded

#check withPage
#check requireMatchingVersion
#check requireErrorFree
#check document

end
end PreviewCompatibility
