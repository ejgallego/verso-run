"""Exercise the public VIR resources API in a real dedicated browser worker."""
import functools, http.server, json, threading, shutil
from pathlib import Path
from playwright.sync_api import sync_playwright

site = Path('/tmp/verso-lean-run-gate-site')
plan = json.loads((site/'gate-publication.json').read_text())
(site/'index.html').write_text('<!doctype html><title>VIR worker gate</title><p>VIR worker gate</p>')
(site/'worker.js').write_text('''let program;
onmessage = async ({data}) => {
  try {
    const {createProgram} = await import(data.module);
    program = await createProgram({runtimeManifestUrl: new URL(data.runtime), programManifestUrl: new URL(data.program),
      expectedExports: {
        "LeanRunGate.greet": {args: [{type: "String", interfaceTag: 3}], result: {type: "String", interfaceTag: 3}, effect: "pure"},
        "LeanRunGate.double": {args: [{type: "Nat", interfaceTag: 0}], result: {type: "Nat", interfaceTag: 0}, effect: "pure"}
      }});
    const natural = program.call("LeanRunGate.double", "9007199254740993");
    const first = [program.call("LeanRunGate.greet", "Unicode 🌍"), String(natural)];
    program.dispose();
    program = await createProgram({runtimeManifestUrl: new URL(data.runtime), programManifestUrl: new URL(data.program)});
    const second = program.call("LeanRunGate.greet", "again");
    program.dispose(); program = null;
    postMessage({ok: true, first, second, natType: typeof natural, worker: typeof document === "undefined"});
  } catch (error) { program?.dispose(); postMessage({ok: false, error: String(error), cause: String(error.cause), stack: error.stack}); }
};''')
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(site))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}/'
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which("google-chrome"))
    page = browser.new_page()
    page.goto(base)
    result = page.evaluate('''async (urls) => await new Promise(resolve => {
      const worker = new Worker("worker.js", {type: "module"});
      worker.onmessage = ({data}) => {worker.terminate(); resolve(data)};
      worker.onerror = e => {worker.terminate(); resolve({ok:false,error:e.message})};
      worker.postMessage(urls);
    })''', dict(module=base+plan['module'], runtime=base+plan['runtime'], program=base+plan['program']))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    (site/'worker-gate-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    assert result.get('ok'), result
    assert result['worker']
    assert result['natType'] == 'bigint'
    assert result['first'] == ['Hello, Unicode 🌍', '18014398509481986'], result
    assert result['second'] == 'Hello, again'
    browser.close()
server.shutdown()
