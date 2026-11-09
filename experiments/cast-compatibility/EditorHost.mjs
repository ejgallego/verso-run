// Copyright (c) 2026 Lean FRO LLC. Released under Apache-2.0.
import React from "react";
import { EditorContext, EnvPosContext, useClientNotificationEffect,
  useServerNotificationEffect, useEvent, useRpcSession } from "@leanprover/infoview";
import { usePage, renderPage } from "verso-cast/preview";
import VirShell from "__VIR_SHELL__";

// Consumer-owned event mapping, following Cast 6bee7e7's reference host. The
// acquisition/decoder/view and VIR shell remain their public implementations.
// This host has no Run workers; execution acceptance belongs to the next gate.
export function PageHost({ uri, ...bridge }) {
  const anchor = React.useMemo(() => ({ uri, line: 0, character: 0 }), [uri]);
  return React.createElement(EnvPosContext.Provider, { value: anchor },
    React.createElement(PageAtUri, { key: uri, uri, ...bridge }));
}

function PageAtUri({ uri, decode, view }) {
  const session = useRpcSession();
  const editor = React.useContext(EditorContext);
  const owner = React.useRef(null);
  const [processing, setProcessing] = React.useState(false);
  const [version, setVersion] = React.useState(undefined);
  const [refresh, setRefresh] = React.useState(0);
  const [stopped, setStopped] = React.useState(false);
  const [selection, setSelection] = React.useState(null);
  const invalidate = () => {
    // Run placement owners will bind directly to this signal in native effects.
    // Abort is synchronous and precedes any replacement render or Wasm call.
    owner.current?.abort();
    setSelection(null);
  };
  useClientNotificationEffect("textDocument/didChange", event => {
    if (event.textDocument.uri !== uri || event.contentChanges.length === 0) return;
    invalidate();
    setVersion(event.textDocument.version);
    setProcessing(true);
  }, [uri]);
  useServerNotificationEffect("$/lean/fileProgress", event => {
    if (event.textDocument.uri !== uri) return;
    const busy = event.processing.length > 0;
    if (busy && owner.current && !owner.current.signal.aborted) {
      invalidate();
      // A busy/finished pair can batch back to processing=false. Preserve the
      // invalidation so that pair still creates one replacement selection.
      setRefresh(value => value + 1);
    }
    setProcessing(busy);
  }, [uri]);
  useEvent(editor.events.serverStopped, () => {
    invalidate(); setStopped(true);
  }, [uri]);
  useEvent(editor.events.serverRestarted, () => {
    invalidate(); setStopped(false); setProcessing(false); setVersion(undefined);
    setRefresh(value => value + 1);
  }, [uri]);
  React.useLayoutEffect(() => {
    if (processing || stopped) return;
    const controller = new AbortController();
    owner.current = controller;
    setSelection(Object.freeze({ session, uri, expectedVersion: version, signal: controller.signal }));
    return () => { controller.abort(); owner.current = null; };
  }, [session, uri, version, processing, stopped, refresh]);
  return React.createElement(Preview, { selection, decode, view });
}

function Preview({ selection, decode, view }) {
  const state = usePage(selection, decode);
  const message = state.status.kind === "loading" ? "Loading page…" :
    state.status.kind === "error" ? state.status.message :
    state.status.kind === "idle" ? "Waiting for a checked page…" : "";
  return React.createElement("section", { "data-cast-preview-current": state.matchesSelection },
    React.createElement("p", { role: "status" }, message),
    renderPage({ view }, state));
}

export default function Widget(props) {
  return React.createElement(VirShell, { ...props, pageHost: PageHost });
}
