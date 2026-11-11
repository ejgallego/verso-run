// Only the widget-loading shell is controlled; the View and Cast component are real Lean/Wasm.
import React from "react";
import { PageHost } from "../web/cast/page.js";

function ObservedHost({ preview, ...props }) {
  const observed = React.useMemo(() => function ObservedPreview(input) {
    React.useLayoutEffect(() => {
      if (input.selection) {
        globalThis.castFixture.selections.push(input.selection);
        globalThis.castFixture.inputs.push(input);
      }
    }, [input.selection, input.onFatal]);
    return React.createElement(preview, input);
  }, [preview]);
  return React.createElement(PageHost, { ...props, preview: observed });
}
export default function Shell(props) {
  if (globalThis.castFixture.unhealthy) throw Error("Lean view unavailable");
  return React.createElement(globalThis.castPlacementView, {
    ...props, pageHost: ObservedHost, pos: { uri: "file:///Demo.lean", line: 5, character: 0 },
  });
}
