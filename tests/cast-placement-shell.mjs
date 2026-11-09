// Controlled Lean/VIR view boundary; native placement ownership remains real.
import React from "react";
const decode = (session, reply) => ({ ok: true, value: { page: {
  session, snapshotRef: reply.snapshotRef, uri: reply.uri, version: reply.version, hasErrors: reply.hasErrors,
} } });
function View({ data, matchesSelection }) {
  const f = globalThis.castFixture;
  if (f.unhealthy) throw Error("Lean view unavailable");
  return React.createElement(React.Fragment, null, ...["a", "b"].map(key =>
    React.createElement(f.placement, { key, page: data.page, matchesSelection,
      description: f.description, controlsHtml: f.controls })));
}
export default function Shell({ pageHost: PageHost, runPlacement }) {
  globalThis.castFixture.placement = runPlacement;
  return React.createElement(PageHost, { uri: "file:///Demo.lean", decode, view: View });
}
