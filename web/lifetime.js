// Stop settles our wait; dynamic import itself can still evaluate. Promise.race
// observes late rejection even after the placement has retired.
export function waitForSignal(promise, signal) {
  let abort;
  const cancelled = new Promise((_, reject) => {
    abort = () => reject(signal.reason);
    if (signal.aborted) abort();
    else signal.addEventListener("abort", abort, { once: true });
  });
  return Promise.race([promise, cancelled]).finally(() => signal.removeEventListener("abort", abort));
}
