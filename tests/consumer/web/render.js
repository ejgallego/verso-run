// Neutral fixture: explicit, silent WebAudio playback exposes owned side effects.
export function mount(slot, { signal }) {
  const text = document.createElement("p");
  text.className = "packet-value";
  const play = document.createElement("button");
  play.type = "button";
  play.textContent = "Play";
  slot.append(text, play);
  const element = slot.closest(".lean-run");
  let context, source, currentSignal, ticket = 0;
  element.dataset.mounts = String(Number(element.dataset.mounts || 0) + 1);
  function pause() {
    ++ticket;
    source?.stop();
    source?.disconnect();
    source = null;
    element.dataset.playing = "false";
  }
  function clear() { pause(); text.textContent = ""; }
  play.addEventListener("click", async () => {
    if (currentSignal?.aborted || signal.aborted || document.hidden) return;
    const generation = ++ticket;
    context ??= new AudioContext();
    await context.resume();
    if (generation !== ticket || signal.aborted || currentSignal.aborted) return;
    source?.stop();
    source = context.createOscillator();
    const gain = context.createGain();
    gain.gain.value = 0;
    source.connect(gain).connect(context.destination);
    source.start();
    element.dataset.playing = "true";
  }, { signal });
  return {
    show(value, { signal: resultSignal }) {
      currentSignal = resultSignal;
      resultSignal.addEventListener("abort", pause, { once: true });
      text.textContent = JSON.stringify({ label: value.label, bytes: Array.from(value.bytes) });
    },
    clear, pause,
    dispose() {
      pause();
      if (context) void context.close();
      element.dataset.closed = "true";
      element.dataset.disposals = String(Number(element.dataset.disposals || 0) + 1);
      slot.replaceChildren();
    },
  };
}
