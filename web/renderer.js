import { ExperimentHost } from "./host.js";
import { AutomatonPlayer } from "./automaton.js";
import { ViewHost } from "./presenter.js";
import { validateInput, scalarKind } from "./contract.js";
const owners = new Set();
addEventListener("pagehide", event => {
  for (const owner of owners) {
    // A cached page retains its controls and listeners when Back restores it.
    if (event.persisted) owner.stop("idle");
    else owner.dispose();
  }
  if (!event.persisted) owners.clear();
});
addEventListener("visibilitychange", () => {
  if (document.hidden) for (const owner of owners) owner.pause();
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
  const clearResult = () => view?.clear();
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
          const generation = view.generation;
          const active = () => ready && generation === view.generation && !document.hidden;
          automatonElement.querySelector(".lean-run-play").addEventListener("click", () => {
            if (!active()) return;
            if (player.playing) player.pause(); else player.play();
          });
          automatonElement.querySelector(".lean-run-step").addEventListener("click", () => {
            if (active()) void player.step();
          });
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
    stop: state => host.stop(state),
    dispose: () => host.dispose(),
    pause: () => { resumeAfterStart = false; player?.pause(); },
  };
  owners.add(owner);
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
  });
  stop.addEventListener("click", () => host.stop());
  element.addEventListener("lean-run-stop", () => host.stop());
  element.addEventListener("lean-run-dispose", () => {
    host.dispose();
    owners.delete(owner);
  });
  input.addEventListener("input", () => {
    if (automatonElement) inputState();
    else host.stop("idle");
  });
  if (input.tagName === "TEXTAREA") input.addEventListener("keydown", event => {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit();
    }
  });
}
