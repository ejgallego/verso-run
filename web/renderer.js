import { ExperimentHost } from "./host.js";
import { AutomatonPlayer } from "./automaton.js";
import { ViewHost } from "./presenter.js";
import { validateInput, scalarKind } from "./contract.js";
const owners = new Map();
addEventListener("pagehide", event => {
  for (const owner of owners.values()) {
    // A cached page retains its controls and listeners when Back restores it.
    if (event.persisted) owner.stop("idle");
    else owner.dispose();
  }
  if (!event.persisted) owners.clear();
});
addEventListener("visibilitychange", () => {
  if (document.hidden) for (const owner of owners.values()) owner.pause();
});
let instance = 0;
export function enhance(element) {
  // Reveal can clone the marker without cloning a placement's ownership.
  const existing = owners.get(element);
  if (existing) return existing;
  const lifetime = new AbortController();
  const binding = { signal: lifetime.signal };
  const description = JSON.parse(element.dataset.experiment);
  const form = element.querySelector("form");
  const input = form.querySelector("input, select, textarea");
  if (input.tagName === "TEXTAREA") input.value = description.initialInput;
  const run = form.querySelector('[type="submit"]');
  const stop = form.querySelector(".lean-run-stop");
  const status = element.querySelector(".lean-run-status");
  const output = element.querySelector(".lean-run-output");
  const preview = element.querySelector(".lean-run-preview");
  const sequenceElement = element.querySelector(".lean-run-sequence");
  const automatonElement = element.querySelector(".lean-run-automaton");
  let ready = false;
  let appliedInput = null;
  let resumeAfterStart = false;
  let presenting = Promise.resolve(true);
  const note = element.querySelector(".lean-run-input-note");
  const inputState = () => {
    if (!automatonElement) return;
    run.textContent = ready ? "Restart" : "Run";
    note.textContent = ready && input.value !== appliedInput ? "Edits apply on Restart." : "";
  };
  let player;
  const liveControls = () => {
    if (!automatonElement) return;
    const play = automatonElement.querySelector(".lean-run-play");
    const step = automatonElement.querySelector(".lean-run-step");
    if (!play || !step) return;
    play.textContent = player.playing ? "Pause" : "Play";
    play.setAttribute("aria-pressed", String(player.playing));
    play.disabled = !ready;
    step.disabled = !ready || player.playing || player.pending;
    // An error observation is not playable, but its worker still belongs to
    // this placement and must remain explicitly stoppable.
    stop.disabled = !host.worker && !busy;
    if (ready && !busy) status.textContent = player.playing ? "Playing" : "Paused";
  };
  let busy = false;
  const setState = (state, value = "") => {
    element.dataset.state = state;
    busy = ["loading", "running", "loading view", "advancing"].includes(state);
    run.disabled = busy && !(automatonElement && ready);
    stop.disabled = !busy && !(automatonElement && ready);
    status.textContent = automatonElement && ready && (state === "success" || state === "advancing") ?
      (player.playing ? "Playing" : state === "advancing" ? "Advancing" : "Paused") :
      state === "idle" ? "Ready" :
      state === "success" && sequenceElement ? "Trace ready" :
      state[0].toUpperCase() + state.slice(1);
    output.textContent = value;
    inputState();
  };
  const pane = automatonElement || sequenceElement || preview;
  const view = pane ? new ViewHost(pane, automatonElement ? "automaton" : sequenceElement ? "sequence" : "html", error => {
    if (automatonElement) host.stop();
    setState("failed", `Could not display the view. Try Run again. ${error.message}`);
  }) : null;
  let viewControls = null;
  const clearResult = () => {
    viewControls?.abort();
    viewControls = null;
    view?.clear();
  };
  const host = new ExperimentHost(description, (state, value = "") => {
    if (["idle", "stopped", "failed"].includes(state)) resumeAfterStart = false;
    if (automatonElement && state === "advancing") {
      setState(state);
      liveControls();
      return;
    }
    if (automatonElement && state === "success" && view.program) {
      presenting = view.update(value).then(shown => {
        if (!shown) return false;
        if (value.error.kind === "some") { ready = false; player.pause(); }
        setState("success");
        liveControls();
        return true;
      });
      return;
    }
    if (automatonElement) { ready = false; player.reset(); }
    clearResult();
    setState(state, state === "success" && view ? "" : value);
    if (state === "success" && view) {
      setState("loading view");
      void view.show(value).then(shown => {
        if (!shown) return;
        setState("success");
        if (automatonElement) {
          ready = value.error.kind === "none";
          viewControls = new AbortController();
          const controls = { signal: viewControls.signal };
          const generation = view.generation;
          const active = () => ready && generation === view.generation && !document.hidden;
          automatonElement.querySelector(".lean-run-play").addEventListener("click", () => {
            if (!active()) return;
            if (player.playing) player.pause(); else player.play();
          }, controls);
          automatonElement.querySelector(".lean-run-step").addEventListener("click", () => {
            if (active()) void player.step();
          }, controls);
          inputState();
          liveControls();
          if (ready && resumeAfterStart && !document.hidden) player.play();
          resumeAfterStart = false;
        }
      });
    }
  });
  if (automatonElement) {
    player = new AutomatonPlayer(async () => {
      await host.advance();
      if (!await presenting) throw new DOMException("Presentation stopped", "AbortError");
    }, liveControls);
  }
  // A placement owns execution, presentation and pending playback intent.
  // Hiding it cancels automatic resumption even while Restart is loading.
  const owner = {
    signal: lifetime.signal,
    stop: state => { if (!lifetime.signal.aborted) host.stop(state); },
    dispose: () => {
      if (lifetime.signal.aborted) return;
      lifetime.abort();
      try { host.dispose(); }
      finally {
        owners.delete(element);
        delete element.dataset.enhanced;
        run.disabled = true;
        stop.disabled = true;
      }
    },
    pause: () => {
      if (lifetime.signal.aborted) return;
      resumeAfterStart = false;
      player?.pause();
    },
  };
  run.disabled = false;
  form.addEventListener("submit", event => {
    event.preventDefault();
    if (busy && !(automatonElement && ready)) return;
    try { validateInput(scalarKind(description.form), input.value); }
    catch (error) {
      host.stop("idle");
      setState("invalid input", error.message);
      return;
    }
    if (automatonElement) {
      const wasPlaying = player.playing;
      host.stop("idle");
      resumeAfterStart = wasPlaying;
      appliedInput = input.value;
    }
    host.invoke(input.value).catch(() => {}); // Host owns all state/error reporting.
  }, binding);
  stop.addEventListener("click", () => owner.stop(), binding);
  element.addEventListener("lean-run-stop", () => owner.stop(), binding);
  element.addEventListener("lean-run-dispose", () => owner.dispose(), binding);
  input.addEventListener("input", () => {
    if (automatonElement) inputState();
    else host.stop("idle");
  }, binding);
  if (input.tagName === "TEXTAREA") input.addEventListener("keydown", event => {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit();
    }
  }, binding);
  owners.set(element, owner);
  element.dataset.enhanced = "true";
  element.dataset.instance = `lean-run-${++instance}`;
  return owner;
}
