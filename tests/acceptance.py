"""Real native/browser acceptance; run from the optional package with uv/Playwright."""
import argparse, functools, http.server, json, shutil, subprocess, tempfile, threading, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--mutations', action='store_true')
parser.add_argument('--output', default='/tmp/verso-lean-run-acceptance')
args = parser.parse_args()
OUTPUT = Path(args.output)
OUTPUT.mkdir(parents=True, exist_ok=True)
results = []

def record(name, **details):
    results.append(dict(test=name, result='pass', **details))
    print('PASS', name, flush=True)

def command(arguments, name, expected=0, cwd=ROOT):
    run = subprocess.run(arguments, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUTPUT/(name+'.log')).write_text(run.stdout)
    if expected == 0: assert run.returncode == 0, run.stdout[-5000:]
    else: assert run.returncode != 0, run.stdout
    return run.stdout

def generate(path):
    command(['lake', 'exe', 'lean-run-demo', '--output', str(path), '--with-tex', '--with-html-single', '--depth', '2'], 'generate-'+path.name)

def oracle(role, value):
    output = subprocess.check_output([str(ROOT/'.lake/build/bin/lean-run-oracle'), role, value], cwd=ROOT, text=True)
    return json.loads(output)

command(['lake','build'], 'build')
site = OUTPUT/'site'
generate(site)
# MultiVerso requires a project marker even when no remotes are configured.
# Supply only that marker: no source tree, Lake cache, or producer resources.
(OUTPUT/'lean-toolchain').write_text((ROOT/'lean-toolchain').read_text())
command([str(ROOT/'.lake/build/bin/lean-run-demo'), '--output', str(OUTPUT/'native-only'), '--with-html-single'], 'native-outside-checkout', cwd=OUTPUT)
record('native publisher runs with only a project marker and embedded assets')
plan = json.loads((site/'html-multi/lean-run/publication.json').read_text())
for name, expected in json.loads((ROOT/'tests/negative/cases.json').read_text()).items():
    output = command(['lake','env','lean',f'tests/negative/{name}.lean'], 'negative-'+name, expected=1)
    assert expected.lower() in output.lower(), output
    assert 'tests/negative/' in output, output
    record('author '+name)

dependency_error = command(['lake','build','+UnavailableDependency:vir'], 'unavailable-dependency', expected=1)
assert 'unsupportedExprText' in dependency_error and 'Lean.Expr.dbgToString' in dependency_error, dependency_error
record('unavailable executable dependency fails with declaration provenance')

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
    def handle(self):
        try: super().handle()
        except (BrokenPipeError, ConnectionResetError): pass
server_root = OUTPUT/'served'
server_root.mkdir(exist_ok=True)
shutil.copytree(site/'html-multi', server_root/'root', dirs_exist_ok=True)
shutil.copytree(site/'html-multi', server_root/'nested'/'prefix'/'manual', dirs_exist_ok=True)
shutil.copytree(site/'html-single', server_root/'single', dirs_exist_ok=True)
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), functools.partial(QuietHandler, directory=str(server_root)))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}/'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page(viewport={'width':1280,'height':1100})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    workers = []
    page.on('worker', lambda worker: workers.append(worker))

    def form_for(declaration, index=0):
        return page.locator('.lean-run').filter(has=page.locator('input')).filter(
            visible=True).nth(index) if declaration is None else page.locator(
            '.lean-run[data-experiment*="'+declaration+'"]:visible').nth(index)

    def call(form, value):
        form.locator('input').fill(value)
        form.locator('[type=submit]').click()
        page.wait_for_function('(e) => ["success","failed"].includes(e.dataset.state)', arg=form.element_handle(), timeout=20000)
        assert form.get_attribute('data-state') == 'success', form.inner_text()
        return form.locator('.lean-run-output').text_content()

    page.goto(base+'single/')
    page.wait_for_selector('.lean-run[data-enhanced]')
    greeting = form_for('LeanRunGate.greet')
    numeric = form_for('LeanRunGate.double')
    other = form_for('LeanRunGate.greet', 1)
    spin = form_for('LeanRunGate.spin')
    assert not workers, 'Runtime must be lazy'
    record('no runtime on page load')
    for value in ['', 'Ada', 'Unicode λ 🌍', '<img src=x onerror=alert(1)>']:
        assert call(greeting,value) == oracle('greet',value)
        assert greeting.locator('.lean-run-output img').count() == 0
    record('native/browser String oracle: empty, edited, Unicode, HTML text')
    for value in ['0','7','9007199254740993','9'*128]:
        assert call(numeric,value) == oracle('double',value)
    record('native/browser exact Nat oracle: zero, edited, large integers')
    assert call(other,'independent') == oracle('greet','independent')
    assert greeting.locator('.lean-run-output').text_content() == oracle('greet','<img src=x onerror=alert(1)>')
    assert len(set(page.locator('.lean-run').evaluate_all('(es) => es.map(e => e.dataset.instance)'))) == 4
    record('independent repeated placements')
    for value in ['-1','1.5','abc','',' 1','1e3','9'*257]:
        numeric.locator('input').fill(value)
        count = len(workers)
        numeric.locator('[type=submit]').click()
        assert numeric.locator('.lean-run-status').text_content() == 'Invalid input'
        assert len(workers) == count
    record('invalid natural inputs rejected before invocation')
    greeting.locator('input').fill('changed')
    assert greeting.locator('.lean-run-output').text_content() == ''
    record('changed input clears prior result')
    assert call(spin,'10') == oracle('spin','10')
    spin.locator('input').fill('1000000000000')
    spin.locator('[type=submit]').click()
    page.wait_for_function('(e) => e.dataset.state === "running"', arg=spin.element_handle())
    assert spin.locator('[type=submit]').is_disabled()
    count = len(workers)
    # Let the real Wasm computation run before terminating its worker.
    page.wait_for_timeout(150)
    spin.locator('.lean-run-stop').click()
    assert spin.locator('.lean-run-status').text_content() == 'Stopped'
    assert call(spin,'11') == oracle('spin','11')
    assert len(workers) == count + 1, 'Run after Stop must create a fresh worker'
    record('real long-running Wasm interrupted and fresh runtime rerun')

    page.reload()
    page.wait_for_selector('.lean-run[data-enhanced]')
    greeting = form_for('LeanRunGate.greet')
    held = []
    page.route('**/runtime.wasm', lambda route: held.append(route))
    greeting.locator('input').fill('late')
    greeting.locator('[type=submit]').click()
    page.wait_for_function('(e) => e.dataset.state === "loading"', arg=greeting.element_handle())
    deadline = time.monotonic()+10
    while not held and time.monotonic()<deadline: page.wait_for_timeout(50)
    assert held
    greeting.locator('.lean-run-stop').click()
    for route in held: route.abort()
    page.unroute('**/runtime.wasm')
    page.wait_for_timeout(150)
    assert greeting.locator('.lean-run-status').text_content() == 'Stopped'
    assert greeting.locator('.lean-run-output').text_content() == ''
    assert call(greeting,'after load stop') == oracle('greet','after load stop')
    record('pending creation stop and stale completion suppression')

    page.reload()
    page.wait_for_selector('.lean-run[data-enhanced]')
    greeting = form_for('LeanRunGate.greet')
    page.route('**/program.irpkg', lambda route: route.fulfill(status=404, body='missing'))
    greeting.locator('input').fill('failure')
    greeting.locator('[type=submit]').click()
    page.wait_for_function('(e) => e.dataset.state === "failed"', arg=greeting.element_handle())
    assert '404' in greeting.locator('.lean-run-output').text_content()
    count = len(workers)
    page.unroute('**/program.irpkg')
    page.wait_for_timeout(150)
    assert len(workers) == count and greeting.get_attribute('data-state') == 'failed'
    assert call(greeting,'explicit retry') == oracle('greet','explicit retry')
    record('resource failure is useful and never automatically replayed')

    count = len(workers)
    page.evaluate('dispatchEvent(new PageTransitionEvent("pagehide", {persisted: true}))')
    assert greeting.get_attribute('data-state') == 'idle'
    assert greeting.locator('.lean-run-output').text_content() == ''
    assert call(greeting,'restored page') == oracle('greet','restored page')
    assert len(workers) == count + 1
    record('cached-page lifecycle handler discards runtime and permits fresh invocation')

    page.evaluate('window.scrollTo(0, 0)')
    page.wait_for_timeout(50)
    page.screenshot(path=str(OUTPUT/'manual.png'), full_page=True)
    for path in ['root/Greeting/', 'nested/prefix/manual/Greeting/']:
        page.goto(base+path)
        page.wait_for_selector('.lean-run[data-enhanced]')
        assert call(form_for('LeanRunGate.greet'),'relocated') == oracle('greet','relocated')
    record('copied output executes from root and nested page/prefix')
    context = browser.new_context(java_script_enabled=False)
    plain = context.new_page()
    plain.goto(base+'single/')
    assert 'public def LeanRunGate.greet' in plain.locator('body').inner_text()
    assert '#check Nat.add' in plain.locator('body').inner_text()
    assert plain.locator('.lean-run [type=submit]').first.is_disabled()
    assert plain.locator('.lean-run noscript').count() == 4
    assert all('Enable JavaScript' in text for text in plain.locator('.lean-run noscript').all_text_contents())
    context.close()
    tex=(site/'tex/main.tex').read_text()
    assert 'LeanRunGate' in tex and 'Nat.add' in tex
    record('JavaScript-disabled highlighting and TeX source fallback')
    assert not errors, errors

    if args.mutations:
        chapter=ROOT/'gates/LeanRunGate/Chapter.lean'
        helper=ROOT/'gates/LeanRunGate/Helper.lean'
        originals={chapter:chapter.read_text(),helper:helper.read_text()}
        identity=plan['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest']
        try:
            for source, before, after, role, value in [
                (chapter,'"Hello, "','"Welcome, "','greet','edited source'),
                (helper,'n + n','n + n + 1','double','9007199254740993')]:
                source.write_text(originals[source].replace(before,after))
                command(['lake','build'],'mutate-'+role)
                changed=OUTPUT/('mutation-'+role)
                generate(changed)
                changed_plan=json.loads((changed/'html-single/lean-run/publication.json').read_text())
                assert changed_plan['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest'] != identity
                assert changed_plan['runtimeManifest'] == plan['runtimeManifest']
                shutil.copytree(changed/'html-single',server_root/('mutation-'+role),dirs_exist_ok=True)
                page.goto(base+'mutation-'+role+'/')
                page.wait_for_selector('.lean-run[data-enhanced]')
                assert call(form_for('LeanRunGate.'+role),value) == oracle(role,value)
                record('implementation invalidation '+role, program=changed_plan['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest'])
                source.write_text(originals[source])
        finally:
            for source, text in originals.items(): source.write_text(text)
            command(['lake','build'],'restore-build')
            generate(site)
        restored=json.loads((site/'html-multi/lean-run/publication.json').read_text())
        assert restored == plan
        record('restored program identity matches original')
    browser.close()
server.shutdown()
(OUTPUT/'results.json').write_text(json.dumps(dict(checks=results,publication=plan),ensure_ascii=False,indent=2)+'\n')
print(f'{len(results)} checks passed; evidence: {OUTPUT}',flush=True)
