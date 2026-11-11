// Copyright (c) 2026 Lean FRO LLC. Released under Apache-2.0.
import React from "react";
import { EditorContext, EnvPosContext, useClientNotificationEffect,
  useServerNotificationEffect, useEvent, useRpcSession } from "@leanprover/infoview";

// One native selection lifetime for the displayed Manual page. Anchor RPC at
// the imported header so ordinary cursor movement does not select a new session.
export function PageHost({ uri, preview }) {
  const anchor = React.useMemo(() => ({ uri, line: 0, character: 0 }), [uri]);
  return React.createElement(EnvPosContext.Provider, { value: anchor },
    React.createElement(PageAtUri, { key: uri, uri, preview }));
}

function PageAtUri({ uri, preview }) {
  const session = useRpcSession();
  const editor = React.useContext(EditorContext);
  const owner = React.useRef(null);
  const committed = React.useRef(null);
  const [failure, setFailure] = React.useState(null);
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
  useClientNotificationEffect("textDocument/didClose", event => {
    if (event.textDocument.uri !== uri) return;
    invalidate(); setStopped(true); setProcessing(false); setVersion(undefined);
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
  useEvent(editor.events.serverStopped, reason => {
    // The real editor also sends undefined to clear status on cursor movement.
    // Only a stopped reason retires execution; clearing it permits recovery.
    if (reason) { invalidate(); setStopped(true); }
    else setStopped(false);
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
  React.useLayoutEffect(() => {
    const current = { selection, preview };
    committed.current = current;
    return () => { if (committed.current === current) committed.current = null; };
  }, [selection, preview]);
  const onFatal = React.useMemo(() => {
    const current = () => selection && !selection.signal.aborted &&
      committed.current?.selection === selection && committed.current?.preview === preview;
    // Schedule native React boundary handling after callVoid returns normally.
    // Both checks retain the captured owner; an old failure cannot select a new one.
    return reason => {
      if (!current()) return;
      queueMicrotask(() => {
        if (!current()) return;
        setFailure(previous => current() ? { selection, preview, reason } : previous);
      });
    };
  }, [selection, preview]);
  if (failure && failure.selection === selection && failure.preview === preview &&
      selection && !selection.signal.aborted) throw failure.reason;
  return React.createElement(preview, { selection, onFatal });
}
