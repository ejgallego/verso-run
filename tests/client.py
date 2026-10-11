"""Client-only model import, native publication and independent VIR worker calls."""
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/client-acceptance')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
command = functools.partial(run_command, output=output, cwd=ROOT)
checks = []

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)

command(['lake', 'run', 'check-library-ownership'], 'ownership')
command(['lake', 'build', '+VersoLeanRun.Views:olean'], 'views-build')
command(['lake', 'env', 'lean', 'tests/client/ViewsOnly.lean'], 'view-imports')
record('each source has one Lake owner; Views imports no genre, VIR compiler or DOM modules')
command(['lake', 'build', '+VersoLeanRunPresenter:olean', 'lean-run-client-check'], 'build')
command(['lake', 'env', 'lean', 'tests/client/layers.lean'], 'ordinary-imports')
record('presenter ordinary imports exclude Verso authoring; native carrier excludes VIR compiler and DOM implementation')
site = output/'site'
# The native binary supplies its own complete resources. Run outside the source
# checkout without a Verso document, generator configuration or project marker.
command([str(ROOT/'.lake/build/bin/lean-run-client-check'), str(site)], 'native', cwd=output)
shutil.copy2(ROOT/'tests/client/worker.js', site/'worker.js')
plan = json.loads((site/'plan.json').read_text())
native = json.loads((site/'native.json').read_text())
assert len(list(site.rglob('bundle.json'))) == 2  # runtime and client program
assert plan['expectedExports']['ClientFixture.trace']['effect'] == 'pure'
assert plan['expectedExports']['ClientFixture.start']['effect'] == 'runtime'
assert native[1]['trace']['frames'][0]['html'] == '18446744073709551615'
assert native[1]['trace']['frames'][1]['html'] == '0'
record('plain native client publishes only its program/runtime and compiler-derived contracts, with exact wraparound')
served = output/'served'
for prefix in ['root', 'nested/client']:
    shutil.copytree(site, served/prefix, dirs_exist_ok=True)
with serve_directory(served) as base, sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    for prefix in ['root', 'nested/client']:
        page.goto(base+prefix+'/')
        for expected in native:
            actual = page.evaluate("""async ({plan, seed}) => {
                const worker = new Worker(new URL('worker.js', location.href), {type:'module'});
                try {
                    return await new Promise((resolve, reject) => {
                        worker.onmessage = ({data}) => data.error ? reject(new Error(data.error)) : resolve(data);
                        worker.onerror = event => reject(new Error(event.message));
                        worker.postMessage({plan, seed, base:location.href});
                    });
                } finally { worker.terminate(); }
            }""", {'plan': plan, 'seed': expected['seed']})
            assert actual == expected, (actual, expected)
            assert actual['independent'] == actual['frames'][1]
        record(prefix+': finite/live views execute without a Verso host and match native frames, with independent sessions')
    browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks, 'publication': plan}, indent=2)+'\n')
print(f'{len(checks)} client checks passed; evidence: {output}', flush=True)
