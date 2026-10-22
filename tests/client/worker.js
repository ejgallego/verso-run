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
    const render = frame => ({label:frame.label, html:program.call("ClientFixture.render", frame), error:frame.error});
    const session = program.call("ClientFixture.start", BigInt(seed));
    const other = program.call("ClientFixture.start", BigInt(seed));
    const frames = [session.initial];
    for (let i = 0; i < 5; ++i) frames.push(session.advance());
    postMessage({ seed, trace: { frames: [trace.initial, ...trace.steps].map(render) },
      frames: frames.map(render), independent: render(other.advance()) });
  } catch (error) {
    postMessage({ error: String(error.stack ?? error) });
  } finally { program?.dispose(); }
};
