// Schedule one worker transition at a time. Pause lets the current transition
// finish; Stop invalidates it through the host's generation and worker lifetime.
export class AutomatonPlayer {
  constructor(advance, changed = () => {}, interval = 200) {
    this.advance = advance;
    this.changed = changed;
    this.interval = interval;
    this.playing = false;
    this.pending = false;
    this.timer = null;
    this.generation = 0;
  }
  play() {
    this.playing = true;
    this.changed();
    if (!this.pending) void this.step();
  }
  pause() {
    this.playing = false;
    clearTimeout(this.timer);
    this.timer = null;
    this.changed();
  }
  reset() {
    ++this.generation;
    this.pending = false;
    this.pause();
  }
  async step() {
    if (this.pending) return;
    clearTimeout(this.timer);
    this.timer = null;
    const generation = this.generation;
    this.pending = true;
    this.changed();
    try { await this.advance(); }
    catch { if (generation === this.generation) this.pause(); }
    finally {
      if (generation === this.generation) {
        this.pending = false;
        this.changed();
        if (this.playing) this.timer = setTimeout(() => this.step(), this.interval);
      }
    }
  }
}
