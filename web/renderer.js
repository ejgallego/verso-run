import { ExperimentHost } from "./host.js";
import { AutomatonPlayer } from "./automaton.js";
import { ViewHost } from "./presenter.js";
import { validateInput, scalarKind } from "./contract.js";
const owners = new Set();
addEventListener("pagehide", event => {
  for (const host of owners) {
    // A cached page retains its controls and listeners when Back restores it.
    if (event.persisted) host.stop("idle");
    else host.dispose();
  }
  if (!event.persisted) owners.clear();
});
addEventListener("visibilitychange", () => {
  if (document.hidden) for (const host of owners) host.player?.pause();
});
let instance = 0;
export function enhance(element) {
  if (element.dataset.enhanced) return;
  element.dataset.enhanced = "true";
  element.dataset.instance = `lean-run-${++instance}`;
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
    stop.disabled = !ready && !busy;
    if (ready && !busy) status.textContent = player.playing ? "Playing" : "Paused";
  };
  let busy = false;
  const setState = (state, value = "") => {
    element.dataset.state = state;
    busy = ["loading", "running", "loading view", "advancing"].includes(state);
    run.disabled = busy;
    stop.disabled = !busy && !(automatonElement && ready);
    status.textContent = automatonElement && ready && (state === "success" || state === "advancing") ?
      (player.playing ? "Playing" : state === "advancing" ? "Advancing" : "Paused") :
      state === "idle" ? "Ready" :
      state === "success" && sequenceElement ? "Trace ready" :
      state[0].toUpperCase() + state.slice(1);
    output.textContent = value;
  };
  const pane = automatonElement || sequenceElement || preview;
  const view = pane ? new ViewHost(pane, automatonElement ? "automaton" : sequenceElement ? "sequence" : "html", error => {
    if (automatonElement) host.stop();
    setState("failed", `Could not display the view. Try Run again. ${error.message}`);
  }) : null;
  const clearResult = () => view?.clear();
  const host = new ExperimentHost(description, (state, value = "") => {
    if (automatonElement && state === "advancing") {
      setState(state);
      liveControls();
      return;
    }
    if (automatonElement && state === "success" && view.program) {
      try { view.update(value); }
      catch (error) { host.fail(error); return; }
      if (value.error !== null) { ready = false; player.pause(); }
      setState("success");
      liveControls();
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
          ready = value.error === null;
          automatonElement.querySelector(".lean-run-play").addEventListener("click", () => {
            if (player.playing) player.pause(); else player.play();
          });
          automatonElement.querySelector(".lean-run-step").addEventListener("click", () => { void player.step(); });
          liveControls();
        }
      });
    }
  });
  if (automatonElement) {
    player = new AutomatonPlayer(() => host.advance(), liveControls);
    host.player = player;
  }
  owners.add(host);
  run.disabled = false;
  form.addEventListener("submit", event => {
    event.preventDefault();
    if (busy) return;
    try { validateInput(scalarKind(description.form), input.value); }
    catch (error) {
      host.stop("idle");
      setState("invalid input", error.message);
      return;
    }
    host.invoke(input.value).catch(() => {}); // Host owns all state/error reporting.
  });
  stop.addEventListener("click", () => host.stop());
  element.addEventListener("lean-run-stop", () => host.stop());
  element.addEventListener("lean-run-dispose", () => {
    host.dispose();
    owners.delete(host);
  });
  input.addEventListener("input", () => host.stop("idle"));
  if (input.tagName === "TEXTAREA") input.addEventListener("keydown", event => {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit();
    }
  });
}
