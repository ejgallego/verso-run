/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import Compatibility
public import VersoCast.Manual.Preview
public meta import VersoCast.Manual.Preview.Server

public section
namespace PreviewCompatibility
open Lean.Vir Lean.Vir.React

-- Build the public factory without importing the reference-manual consumer.
-- No Input is fabricated: the host still owes a stable session/generation.
def create : RuntimeM
    (FunctionComponent (Props.WithData VersoCast.Manual.Preview.Input)) :=
  VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let handlers ← VersoCast.Manual.createRenderers styles
      pure fun _page => handlers
    onInvalidated := pure ()
    onLoaded := fun _page => pure () }

-- Keep the captured session and reference as native values, not document JSON.
def owningSession (page : VersoCast.Manual.Preview.PageInfo) : Js Infoview.RpcSession :=
  page.session

def nativeReference (page : VersoCast.Manual.Preview.PageInfo) : Js.Any :=
  page.snapshotRef

meta section
open Lean Server VersoCast.Manual.Preview.Server

structure InspectParams where
  snapshotRef : WithRpcRef CheckedPage
  deriving RpcEncodable

-- Compile a consumer-side handler against the public authority/currentness API.
-- This gate does not invoke the RPC or establish freshness in a real editor.
@[server_rpc_method]
def inspect (params : InspectParams) : RequestM (RequestTask String) :=
  RequestM.asTask do
    let page := params.snapshotRef.val
    requireCurrent page
    if page.hasErrors then
      throw ⟨.invalidParams, "Run requires an error-free page"⟩
    let encoded := (toJson page.document).compress
    requireCurrent page
    pure encoded

#check withCheckedPage
#check requireCurrent
#check document

end
end PreviewCompatibility
