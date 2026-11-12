import React from "react";

// Use the actual compiled adapter. Only the editor's widget-loading shell is
// replaced, since this test acquires its IR with the ordinary native fixture.
export default function Shell(props) {
  return React.createElement(globalThis.castMathView, {
    ...props, pos: { uri: "file:///CastMathDoc.lean", line: 5, character: 0 },
  });
}
