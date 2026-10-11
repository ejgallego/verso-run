import assert from "node:assert/strict";
import { ViewHost } from "../web/presenter.js";

// Control paint and deadlines independently of the event loop. These are the
// loaded-document races that an ordinary fast iframe would rarely exercise.
function fixture() {
  const paints = new Map(), timers = new Map();
  let id = 0;
  globalThis.requestAnimationFrame = callback => { paints.set(++id, callback); return id; };
  globalThis.cancelAnimationFrame = key => paints.delete(key);
  globalThis.setTimeout = callback => { timers.set(++id, callback); return id; };
  globalThis.clearTimeout = key => timers.delete(key);
  const listeners = new Set();
  const document = globalThis.document = Object.assign(new EventTarget(), { hidden: false });
  const add = document.addEventListener.bind(document), remove = document.removeEventListener.bind(document);
  document.addEventListener = (type, callback, options) => { listeners.add(callback); add(type, callback, options); };
  document.removeEventListener = (type, callback) => { listeners.delete(callback); remove(type, callback); };
  const frame = new EventTarget(), errors = [];
  const element = { querySelector: () => frame, replaceChildren() {}, hidden: false };
  const view = new ViewHost(element, "automaton", error => errors.push(error.message));
  let commits = 0, disposed = 0;
  view.program = { call(name) { if (name === "commit") ++commits; }, dispose() { ++disposed; } };
  view.declaration = "stage"; view.commit = "commit";
  return {
    view, paints, timers, errors, listeners,
    get commits() { return commits; }, get disposed() { return disposed; },
    load: () => frame.dispatchEvent(new Event("load")),
    hide() { document.hidden = true; document.dispatchEvent(new Event("visibilitychange")); },
    paint() {
      const [key, callback] = paints.entries().next().value;
      paints.delete(key); callback();
    },
  };
}

const value = { label: "Next", html: "<p>Next</p>", error: null };
for (const painted of [0, 1]) {
  const f = fixture(), pending = f.view.update(value);
  f.load();
  for (let i = 0; i < painted; ++i) f.paint();
  f.hide();
  assert.equal(await pending, true);
  assert.equal(f.commits, 1); assert.deepEqual(f.errors, []);
  assert.equal(f.paints.size, 0); assert.equal(f.timers.size, 0); assert.equal(f.listeners.size, 0);
  f.view.clear(); assert.equal(f.disposed, 1);
}
{
  const f = fixture(), pending = f.view.update(value);
  f.hide();
  await Promise.resolve(); assert.equal(f.commits, 0);
  // Hiding cannot make an unloaded sandbox document eligible for commit.
  f.load(); assert.equal(await pending, true); assert.equal(f.commits, 1);
  assert.equal(f.paints.size, 0); assert.equal(f.listeners.size, 0);
  f.view.clear();
}
for (const loaded of [false, true]) {
  const f = fixture(), pending = f.view.update(value);
  if (loaded) f.load();
  f.hide(); f.view.clear();
  assert.equal(await pending, false); f.load();
  assert.equal(f.commits, 0); assert.deepEqual(f.errors, []);
  assert.equal(f.paints.size, 0); assert.equal(f.timers.size, 0); assert.equal(f.listeners.size, 0);
}
{
  const f = fixture(), pending = f.view.update(value);
  f.hide(); [...f.timers.values()][0]();
  assert.equal(await pending, false); f.load();
  assert.match(f.errors[0], /Frame loading timed out/);
  assert.equal(f.commits, 0); assert.equal(f.disposed, 1); assert.equal(f.listeners.size, 0);
}
console.log("loaded/hidden paint races settle once; pending loads, Stop, deadlines and listener lifetimes remain guarded");
