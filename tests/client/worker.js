// This fixture consumes views through VIR directly, without Verso's page host.
onmessage = async ({ data: { base, plan, seed } }) => {
  let program;
  try {
    const url = path => new URL(path, base);
    const { createProgram } = await import(url(plan.runtimeModule));
    program = await createProgram({
      runtimeManifestUrl: url(plan.runtimeManifest),
      programManifestUrl: url(plan.programManifest),
      expectedExports: plan.expectedExports,
    });
    const trace = program.call("ClientFixture.trace", BigInt(seed));
    if (trace.version !== 1n) throw new Error("Unexpected typed trace version");
    const session = program.call("ClientFixture.start", BigInt(seed));
    const other = program.call("ClientFixture.start", BigInt(seed));
    const frames = [session.initial];
    for (let i = 0; i < 5; ++i) frames.push(session.advance());
    postMessage({ seed, trace: { version: 1, frames: trace.frames },
      frames, independent: other.advance() });
  } catch (error) {
    postMessage({ error: String(error.stack ?? error) });
  } finally { program?.dispose(); }
};
