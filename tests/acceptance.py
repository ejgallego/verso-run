"""Real native/browser acceptance; run from the repository root with uv/Playwright."""
import argparse, copy, functools, http.server, json, re, shutil, subprocess, sys, tempfile, threading, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--mutations', action='store_true')
parser.add_argument('--output', default='/tmp/verso-lean-run-acceptance')
args = parser.parse_args()
OUTPUT = Path(args.output).resolve()
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
command(['node', 'tests/host-lifecycle.mjs'], 'host-lifecycle')
record('publication acquisition cancellation, shared waiters, late completion, deadline and explicit recovery')
site = OUTPUT/'site'
generate(site)
# MultiVerso requires a project marker even when no remotes are configured.
# Supply only that marker: no source tree, Lake cache, or producer resources.
(OUTPUT/'lean-toolchain').write_text((ROOT/'lean-toolchain').read_text())
command([str(ROOT/'.lake/build/bin/lean-run-demo'), '--output', str(OUTPUT/'native-only'), '--with-html-single'], 'native-outside-checkout', cwd=OUTPUT)
record('native publisher runs with only a project marker and embedded assets')
plan = json.loads((site/'html-multi/lean-run/publication.json').read_text())
assert plan == json.loads((site/'html-single/lean-run/publication.json').read_text())
assert plan == json.loads((OUTPUT/'native-only/html-multi/lean-run/publication.json').read_text())
published = plan['programs']['LeanRunGate.Chapter']
for declaration, type_name in [('greet', 'String'), ('Stack.run', 'String'), ('htmlGreeting', 'String'), ('diagram', 'String'), ('double', 'Nat'), ('Helper.twice', 'Nat'), ('spin', 'Nat')]:
    contract = published['LeanRunGate.'+declaration]['expectedExport']
    assert set(contract) == {'args', 'result', 'effect'}
    assert contract['effect'] == 'pure'
    assert len(contract['args']) == 1
    assert contract['args'][0]['type'] == type_name
    assert contract['result']['type'] == type_name
chapter_manifest = json.loads((site/'html-multi'/published['LeanRunGate.greet']['manifest']).read_text())
helper_manifest = json.loads((site/'html-multi'/published['LeanRunGate.Helper.twice']['manifest']).read_text())
assert chapter_manifest['descriptor']['logicalId'] == 'LeanRunGate.Chapter'
assert helper_manifest['descriptor']['logicalId'] == 'LeanRunGate.Chapter'
assert chapter_manifest['descriptor']['schemaVersion'] == helper_manifest['descriptor']['schemaVersion'] == 2
assert helper_manifest == chapter_manifest
record('entry-selected local/imported callables share a document-owned resource and independent signatures')
command(['lake', 'exe', 'lean-run-resource-set-check'], 'resource-set-adapter')
record('ResourceSet planner preserves legacy bytes, explicit prefixes/runtimes, and rejects conflicting or corrupt runtimes')
legacy = OUTPUT/'legacy-publication'
command(['lake', 'exe', 'lean-run-publication-check', 'legacy', '--output', str(legacy)], 'legacy-publication')
assert plan == json.loads((legacy/'html-multi/lean-run/publication.json').read_text())
def inventory(path):
    return {p.relative_to(path): p.read_bytes() for p in path.rglob('*') if p.is_file()}
assert inventory(site/'html-multi/lean-run') == inventory(legacy/'html-multi/lean-run')
record('legacy Manual Bundle publisher and ResourceSet publisher emit identical execution assets')
duplicates = OUTPUT/'duplicate-registration'
command(['lake', 'exe', 'lean-run-publication-check', 'duplicate', '--output', str(duplicates)],
    'duplicate-registration')
assert plan == json.loads((duplicates/'html-multi/lean-run/publication.json').read_text())
original_files = {p.relative_to(site/'html-multi/lean-run/resources')
    for p in (site/'html-multi/lean-run/resources').rglob('*') if p.is_file()}
duplicate_files = {p.relative_to(duplicates/'html-multi/lean-run/resources')
    for p in (duplicates/'html-multi/lean-run/resources').rglob('*') if p.is_file()}
assert original_files == duplicate_files
record('repeated bundle registration deduplicates resources and keeps declaration bindings')
missing = command(['lake', 'exe', 'lean-run-publication-check', 'missing', '--output',
    str(OUTPUT/'missing-registration')], 'missing-registration', expected=1)
assert 'LeanRunGate.Chapter:' in missing and 'no published program bundle for LeanRunGate.greet' in missing
assert '+Module:virResourcePack' in missing and ':virResourcePack' in missing and 'include_vir_assets' in missing and 'VersoLeanRun.publish' in missing
assert not (OUTPUT/'missing-registration/html-multi/lean-run/publication.json').exists()
record('missing program registration reports declaration and source provenance')
command(['lake', 'env', 'lean', 'tests/HtmlAdapter.lean'], 'html-adapter')
command(['lake', 'env', 'lean', 'tests/EntryRegistration.lean'], 'entry-registration')
record('entry registers unannotated scalar functions and typed Html without an output option')
record('typed HTML adapter serializes escaped text and reuses repeated entry placements')
for name, expected in json.loads((ROOT/'tests/negative/cases.json').read_text()).items():
    output = command(['lake','env','lean',f'tests/negative/{name}.lean'], 'negative-'+name, expected=1)
    details = dict(contains=[expected]) if isinstance(expected, str) else expected
    assert all(text.lower() in output.lower() for text in details['contains']), output
    assert 'tests/negative/' in output, output
    if 'line' in details:
        assert re.search(rf'tests/negative/{name}\.lean:{details["line"]}:\d+: error:', output), output
    if 'notContains' in details:
        assert all(text.lower() not in output.lower() for text in details['notContains']), output
    record('author '+name)

dependency_error = command(['lake','build','+UnavailableDependency:vir'], 'unavailable-dependency', expected=1)
assert 'unsupportedExprText' in dependency_error and 'Lean.Expr.dbgToString' in dependency_error, dependency_error
record('unavailable executable dependency fails with declaration provenance')

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
    def handle(self):
        try: super().handle()
        except (BrokenPipeError, ConnectionResetError): pass
foreign_site = OUTPUT/'foreign-root'
command(['lake','exe','lean-run-blog-demo','--output',str(foreign_site)], 'foreign-root-generate')
foreign_plan = json.loads((foreign_site/'lean-run/publication.json').read_text())
server_root = OUTPUT/'served'
server_root.mkdir(exist_ok=True)
shutil.copytree(site/'html-multi', server_root/'root', dirs_exist_ok=True)
shutil.copytree(site/'html-multi', server_root/'nested'/'prefix'/'manual', dirs_exist_ok=True)
shutil.copytree(site/'html-single', server_root/'single', dirs_exist_ok=True)
shutil.copytree(foreign_site, server_root/'single/foreign-root', dirs_exist_ok=True)
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

    # Exercise the public promise against a held real browser fetch, not only the UI.
    loading = browser.new_page()
    loading.on('pageerror', lambda error: errors.append(str(error)))
    held_publications = []
    loading.route('**/lean-run/publication.json', lambda route: held_publications.append(route))
    loading.goto(base+'single/')
    loading.wait_for_selector('.lean-run[data-enhanced]')

    def start_publication_calls(name, count):
        loading.evaluate('''async ({name, count}) => {
            const {ExperimentHost} = await import(new URL('lean-run/host.js?' + name, location.href).href);
            const description = JSON.parse(document.querySelector(
                '.lean-run[data-experiment*="LeanRunGate.greet"]').dataset.experiment);
            const test = globalThis.loadingCase = {hosts: [], outcomes: [], states: []};
            for (let i = 0; i < count; ++i) {
                test.outcomes[i] = {pending: true};
                const host = new ExperimentHost(description, state => test.states[i] = state);
                test.hosts.push(host);
                host.invoke('placement ' + i).then(value => test.outcomes[i] = {value},
                    error => test.outcomes[i] = {error: error.name});
            }
        }''', {'name': name, 'count': count})

    def wait_publications(count):
        deadline = time.monotonic()+10
        while len(held_publications) < count and time.monotonic() < deadline:
            loading.wait_for_timeout(25)
        assert len(held_publications) == count

    start_publication_calls('publication-stop', 1)
    wait_publications(1)
    loading.evaluate('loadingCase.hosts[0].stop()')
    loading.wait_for_function('loadingCase.outcomes[0].error === "AbortError"', timeout=1000)
    assert loading.evaluate('loadingCase.states[0]') == 'stopped'
    assert not loading.workers
    # Leave the stopped response held; retry must acquire a different request.
    loading.evaluate('''() => {
        loadingCase.hosts[0].invoke('retry').then(value => loadingCase.retry = {value},
            error => loadingCase.retry = {error: error.name});
    }''')
    wait_publications(2)
    held_publications[1].fulfill(content_type='application/json', body=json.dumps(plan))
    loading.wait_for_function('loadingCase.retry?.value !== undefined', timeout=20000)
    assert loading.evaluate('loadingCase.retry.value') == oracle('greet', 'retry')
    loading.evaluate('loadingCase.hosts[0].dispose()')
    # Only now finish the intercepted, already cancelled request in the test harness.
    held_publications[0].abort()
    record('held publication Stop promptly rejects AbortError without a response; fresh fetch and real worker recover')

    start_publication_calls('publication-shared', 2)
    wait_publications(3)
    loading.evaluate('loadingCase.hosts[0].stop()')
    loading.wait_for_function('loadingCase.outcomes[0].error === "AbortError"', timeout=1000)
    assert loading.evaluate('loadingCase.outcomes[1].pending') is True
    held_publications[2].fulfill(content_type='application/json', body=json.dumps(plan))
    loading.wait_for_function('loadingCase.outcomes[1].value !== undefined', timeout=20000)
    assert loading.evaluate('loadingCase.outcomes[1].value') == oracle('greet', 'placement 1')
    loading.evaluate('loadingCase.hosts.forEach(host => host.dispose())')
    loading.close()
    record('simultaneous placements share publication acquisition; stopping one preserves the other real worker call')

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
    calculator = form_for('LeanRunGate.Stack.run')
    html_form = form_for('LeanRunGate.htmlGreeting')
    diagram_form = form_for('LeanRunGate.diagram')
    assert calculator.locator('details').get_attribute('open') is None
    calculator.locator('summary').press('Enter')
    assert calculator.locator('details').get_attribute('open') is not None
    assert 'public inductive Instruction' in calculator.locator('.lean-run-source').inner_text()
    calculator.locator('summary').press('Enter')
    assert calculator.locator('details').get_attribute('open') is None
    assert not workers, 'Runtime must be lazy'
    record('no runtime on page load')
    assert page.evaluate('''async () => {
        const {formatResult, MAX_OUTPUT} = await import(new URL('lean-run/contract.js', document.baseURI));
        if (formatResult('nat', 0n) !== '0' || formatResult('nat', 9007199254740993n) !== '9007199254740993') return false;
        for (const value of [-1n, 1, '1', 1.5, BigInt('9'.repeat(MAX_OUTPUT + 1))]) {
            try { formatResult('nat', value); return false; } catch {}
        }
        return true;
    }''')
    record('Nat BigInt results retain exact display and reject negative, lossy, and oversized values')
    anchored = form_for('LeanRunGate.Helper.twice')
    assert anchored.locator('input').input_value() == '21'
    assert 'public def LeanRunGate.Helper.twice' in anchored.locator('.lean-run-source').inner_text()
    assert 'ANCHOR:' not in anchored.locator('.lean-run-source').inner_text()
    assert anchored.locator('.lean-run-source .hl').count() > 0
    assert call(anchored, '9007199254740993') == oracle('double', '9007199254740993')
    record('anchored imported scalar preserves native highlighting and exact worker execution')
    for value in ['', 'Ada', 'Unicode λ 🌍', '<img src=x onerror=alert(1)>']:
        assert call(greeting,value) == oracle('greet',value)
        assert greeting.locator('.lean-run-output img').count() == 0
    record('native/browser String oracle: empty, edited, Unicode, HTML text')

    assert calculator.locator('input').input_value() == '6 7 * 2 +'
    calculator.locator('[type=submit]').click()
    page.wait_for_function('(e) => e.dataset.state === "success"', arg=calculator.element_handle(), timeout=20000)
    assert calculator.locator('.lean-run-output').text_content() == (
        'Start: []\n6  →  [6]\n7  →  [6, 7]\n*  →  [42]\n2  →  [42, 2]\n+  →  [44]\n\nResult: 44')
    record('stack calculator preset runs the displayed program with a complete trace')
    for value, expected in [
        ('3 4 + 5 *', 35), ('5 dup *', 25), ('2 3 swap dup * +', 7),
        ('9007199254740993 2 *', 18014398509481986), ('  3   4 +  ', 7),
    ]:
        output = call(calculator, value)
        assert output == oracle('stack', value)
        assert output.endswith('Result: '+str(expected)), output
    record('stack calculator native/browser arithmetic, dup, swap and exact large integers')
    for value, expected in [
        ('', 'Enter a program'), ('2 +', "Error at '+': not enough values"),
        ('dup', "Error at 'dup': not enough values"), ('word', "Error at 'word': unknown instruction"),
        ('-1', "Error at '-1': unknown instruction"), ('2 3', 'Finish with exactly one value'),
    ]:
        output = call(calculator, value)
        assert output == oracle('stack', value)
        assert expected in output, output
    record('stack calculator reports parse errors, stack underflow and unfinished programs')
    for value, expected in [
        (' '.join(['1']*33), 'Use at most 32 instructions'),
        (' '.join(['1']*17), 'Stack or number limit reached'),
        ('9'*81, 'Stack or number limit reached'),
        ('9'*80+' 2 *', 'Stack or number limit reached'),
    ]:
        output = call(calculator, value)
        assert output == oracle('stack', value)
        assert expected in output, output
    record('stack calculator bounds instructions, stack depth and arithmetic growth')

    preview = html_form.locator('iframe')
    assert preview.is_hidden() and preview.get_attribute('sandbox') == ''
    for name in ['Ada', '', 'Unicode λ 🌍', '<img src=x onerror=alert(1)>', '& <script>alert(1)</script>']:
        assert call(html_form, name) == ''
        markup = oracle('htmlGreeting', name)
        assert markup in preview.get_attribute('srcdoc')
        heading = html_form.frame_locator('iframe').locator('h2')
        assert heading.inner_text() == 'Hello, '+(name or 'friend')+'!'
        assert html_form.frame_locator('iframe').locator('img,script').count() == 0
        assert heading.evaluate('e => getComputedStyle(e).color') == 'rgb(40, 85, 117)'
    record('HTML greeting matches native markup and renders inline styles with escaped reader input')
    assert html_form.evaluate('''e => {
        try { void e.querySelector('iframe').contentWindow.document; return false; }
        catch (error) { return error.name === 'SecurityError'; }
    }''')
    assert "default-src 'none'" in preview.get_attribute('srcdoc')
    html_form.locator('input').fill('changed')
    assert preview.is_hidden() and preview.get_attribute('srcdoc') is None
    assert call(html_form,'after edit') == ''
    assert html_form.frame_locator('iframe').locator('h2').inner_text() == 'Hello, after edit!'
    record('HTML preview is isolated and cleared on input changes before a fresh invocation')

    assert diagram_form.locator('input').input_value() == '4'
    diagram_widths = []
    for count in [1, 4, 8, 2]:
        assert call(diagram_form, str(count)) == ''
        markup = oracle('diagram', str(count))
        assert markup in diagram_form.locator('iframe').get_attribute('srcdoc')
        frame = diagram_form.frame_locator('iframe')
        svg = frame.locator('svg')
        assert svg.count() == 1
        assert svg.locator('text').all_text_contents() == [str(i+1) for i in range(count)]
        assert svg.locator('path[fill="none"]').count() == 2 * count - 1
        assert svg.locator('path[fill="rgb(237,245,255)"]').count() == count
        assert f'{count} nodes, {count-1} links' in frame.locator('body').inner_text()
        assert svg.locator('script').count() == 0
        assert svg.evaluate('e => e.getBoundingClientRect().width > 0')
        bounds = [float(x) for x in svg.get_attribute('viewBox').split()]
        assert bounds == [-29, -29, (count-1)*60+58, 58]
        diagram_widths.append(bounds[2])
    assert diagram_widths[0] < diagram_widths[1] < diagram_widths[2]
    record('Illuminate SVG drawing commands execute in Wasm with native markup, labels, links and changing geometry')
    for value in ['', '0', '9', '-1', '1.5', 'nodes', '100000000000000000000']:
        assert call(diagram_form, value) == ''
        assert oracle('diagram', value) in diagram_form.locator('iframe').get_attribute('srcdoc')
        frame = diagram_form.frame_locator('iframe')
        assert 'from 1 to 8' in frame.locator('[role=alert]').inner_text()
        assert frame.locator('svg').count() == 0
    assert call(diagram_form, '3') == ''
    assert diagram_form.frame_locator('iframe').locator('svg text').count() == 3
    diagram_form.locator('input').fill('5')
    assert diagram_form.locator('iframe').is_hidden()
    assert call(diagram_form, '5') == ''
    record('Illuminate validates bounded node counts and clears/recreates its preview after edits')

    page.reload()
    page.wait_for_selector('.lean-run[data-enhanced]')
    html_form = form_for('LeanRunGate.htmlGreeting')
    page.route('**/program.irpkg', lambda route: route.fulfill(status=404, body='missing'))
    html_form.locator('[type=submit]').click()
    page.wait_for_function('e => e.dataset.state === "failed"', arg=html_form.element_handle(), timeout=20000)
    assert html_form.locator('iframe').is_hidden()
    assert '404' in html_form.locator('.lean-run-output').text_content()
    page.unroute('**/program.irpkg')
    assert call(html_form,'recovered') == ''
    assert html_form.frame_locator('iframe').locator('h2').inner_text() == 'Hello, recovered!'
    record('HTML resource failure stays plain text and explicit retry restores the preview')

    # Change only the independently published expectation, keeping the real program
    # bytes and resource identity intact. VIR must reject before invoking Lean.
    for field, value in [
        ('args', published['LeanRunGate.double']['expectedExport']['args']),
        ('result', published['LeanRunGate.double']['expectedExport']['result']),
        ('args', []),
        ('effect', 'io'),
        (None, None),
    ]:
        altered = copy.deepcopy(plan)
        binding = altered['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']
        if field is None:
            del binding['expectedExport']
        else:
            binding['expectedExport'][field] = value
        page.route('**/lean-run/publication.json', lambda route: route.fulfill(
            content_type='application/json', body=json.dumps(altered)))
        page.goto(base+'single/')
        page.wait_for_selector('.lean-run[data-enhanced]')
        greeting = form_for('LeanRunGate.greet')
        greeting.evaluate('''e => {
            e.observedStates = [];
            new MutationObserver(() => e.observedStates.push(e.dataset.state))
                .observe(e, {attributes: true, attributeFilter: ['data-state']});
        }''')
        count = len(workers)
        greeting.locator('input').fill('must not run')
        greeting.locator('[type=submit]').click()
        page.wait_for_function('(e) => e.dataset.state === "failed"',
            arg=greeting.element_handle(), timeout=20000)
        assert 'running' not in greeting.evaluate('e => e.observedStates')
        if field is None:
            assert 'No published VIR signature' in greeting.locator('.lean-run-output').text_content()
            assert len(workers) == count
            name = 'missing published signature'
        else:
            assert 'expected callable signature' in greeting.locator('.lean-run-output').text_content()
            name = 'arity' if value == [] else field
        record('reject '+name+' before invocation')
        page.unroute('**/lean-run/publication.json')
    altered = copy.deepcopy(plan)
    altered['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest'] = 'foreign-root/' + foreign_plan['programs']['LeanRunBlog.Page']['LeanRunGate.Helper.twice']['manifest']
    page.route('**/lean-run/publication.json', lambda route: route.fulfill(
        content_type='application/json', body=json.dumps(altered)))
    page.goto(base+'single/')
    page.wait_for_selector('.lean-run[data-enhanced]')
    greeting = form_for('LeanRunGate.greet')
    greeting.evaluate('''e => {
        e.observedStates = [];
        new MutationObserver(() => e.observedStates.push(e.dataset.state))
            .observe(e, {attributes: true, attributeFilter: ['data-state']});
    }''')
    greeting.locator('[type=submit]').click()
    page.wait_for_function('e => e.dataset.state === "failed"', arg=greeting.element_handle(), timeout=20000)
    assert 'running' not in greeting.evaluate('e => e.observedStates')
    assert 'missing program export LeanRunGate.greet' in greeting.locator('.lean-run-output').text_content()
    page.unroute('**/lean-run/publication.json')
    record('wrong root manifest rejects the requested full declaration before invocation')

    page.goto(base+'single/')
    page.wait_for_selector('.lean-run[data-enhanced]')
    greeting = form_for('LeanRunGate.greet')
    assert call(greeting,'<img src=x onerror=alert(1)>') == oracle('greet','<img src=x onerror=alert(1)>')

    for value in ['0','7','9007199254740993','9'*128]:
        assert call(numeric,value) == oracle('double',value)
    record('native/browser exact Nat oracle: zero, edited, large integers')
    assert call(other,'independent') == oracle('greet','independent')
    assert greeting.locator('.lean-run-output').text_content() == oracle('greet','<img src=x onerror=alert(1)>')
    instances = page.locator('.lean-run').evaluate_all('(es) => es.map(e => e.dataset.instance)')
    assert len(set(instances)) == len(instances)
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
    assert 'Could not run LeanRunGate.greet' in greeting.locator('.lean-run-output').text_content()
    assert 'contact the document author' in greeting.locator('.lean-run-output').text_content()
    assert 'resource-fetch' in greeting.locator('.lean-run-output').text_content()
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
    for path in ['root/Illuminate-diagrams/', 'nested/prefix/manual/Illuminate-diagrams/']:
        page.goto(base+path)
        page.wait_for_selector('.lean-run[data-enhanced]')
        form = form_for('LeanRunGate.diagram')
        assert call(form, '6') == ''
        assert oracle('diagram', '6') in form.locator('iframe').get_attribute('srcdoc')
        assert form.frame_locator('iframe').locator('svg text').count() == 6
    record('Illuminate executes from copied root and nested HTTP deployments')
    for path in ['root/Anchored-source/', 'nested/prefix/manual/Anchored-source/']:
        page.goto(base+path)
        page.wait_for_selector('.lean-run[data-enhanced]')
        link = page.locator('p code a').filter(has_text='LeanRunGate.Helper.twice').first
        target = link.get_attribute('href').split('#')[1]
        assert page.locator('[id="'+target+'"]').count() == 1
        link.click()
        page.wait_for_url('**/#'+target)
        assert call(form_for('LeanRunGate.Helper.twice'), '21') == oracle('double', '21')
    record('anchored definition links and execution work at root and nested Manual paths')
    context = browser.new_context(java_script_enabled=False)
    plain = context.new_page()
    plain.goto(base+'single/')
    assert 'public def LeanRunGate.greet' in plain.locator('body').inner_text()
    assert '#check Nat.add' in plain.locator('body').inner_text()
    assert plain.locator('.lean-run [type=submit]').first.is_disabled()
    assert plain.locator('.lean-run noscript').count() == plain.locator('.lean-run').count()
    assert all('Enable JavaScript' in text for text in plain.locator('.lean-run noscript').all_text_contents())
    plain_calculator = plain.locator('.lean-run[data-experiment*="LeanRunGate.Stack.run"]')
    plain_calculator.locator('summary').click()
    assert 'public inductive Instruction' in plain_calculator.locator('.lean-run-source').inner_text()
    plain_diagram = plain.locator('.lean-run[data-experiment*="LeanRunGate.diagram"]')
    plain_diagram.locator('summary').click()
    assert 'public def LeanRunGate.diagram' in plain_diagram.locator('.lean-run-source').inner_text()
    assert 'Svg.render' in plain_diagram.locator('.lean-run-source').inner_text()
    plain_anchor = plain.locator('.lean-run[data-experiment*="LeanRunGate.Helper.twice"]')
    assert 'public def LeanRunGate.Helper.twice' in plain_anchor.locator('.lean-run-source').inner_text()
    assert plain_anchor.locator('[type=submit]').is_disabled()
    context.close()
    tex=(site/'tex/main.tex').read_text()
    assert 'LeanRunGate' in tex and 'Nat.add' in tex and 'Instruction' in tex and 'Svg.render' in tex and 'Helper.twice' in tex
    record('JavaScript-disabled highlighting and TeX source fallback')
    assert not errors, errors

    if args.mutations:
        chapter=ROOT/'demo/chapters/LeanRunGate/Chapter.lean'
        helper=ROOT/'demo/chapters/LeanRunGate/Helper.lean'
        lakefile=ROOT/'lakefile.lean'
        resources=ROOT/'demo/resources'
        moved=ROOT/'_registration-layout/resources'
        carrier=resources/"LeanRunGate/Resources.lean"
        originals={p:p.read_text() for p in [chapter, helper, lakefile, carrier]}
        identity=plan['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest']
        try:
            # A rejected replacement must not launch the generator or replace the
            # last accepted publication. Keep the prior valid site available.
            published_before=(site/'html-multi/lean-run/publication.json').read_bytes()
            chapter.write_text(originals[chapter].replace('"Hello, " ++ name',
                'name ++ toString (Float.atan 0)'))
            rejected=command(['lake','exe','lean-run-demo','--output',str(site),
                '--with-html-single'],'unsupported-rebuild',expected=1)
            assert 'LeanRunGate.greet' in rejected and 'Float.atan' in rejected, rejected
            assert (site/'html-multi/lean-run/publication.json').read_bytes() == published_before
            chapter.write_text(originals[chapter])
            record('unsupported replacement fails before publishing over the last accepted site')

            for name, changed_helper, expected in [
                ('duplicate-anchor', originals[helper] + '\n-- ANCHOR: twice\n', 'Anchor already used: twice'),
                ('unclosed-anchor', originals[helper].replace('-- ANCHOR_END: twice', ''), 'Unclosed anchors: twice'),
                ('stale-anchor-body', originals[helper].replace('n + n', 'n + n + 1'), 'Mismatched code')]:
                helper.write_text(changed_helper)
                rejected = command(['lake', 'exe', 'lean-run-demo', '--output', str(site)],
                    name + '-rebuild', expected=1)
                assert expected in rejected, rejected
                assert (site/'html-multi/lean-run/publication.json').read_bytes() == published_before
                helper.write_text(originals[helper])
                record(name + ' rejects the rebuild and preserves the last accepted publication')

            for source, before, after, role, value in [
                (chapter,'"Hello, "','"Welcome, "','greet','edited source'),
                (helper,'n + n','n + n + 1','double','9007199254740993')]:
                source.write_text(originals[source].replace(before,after))
                if source == helper:
                    # Both ordinary and runnable anchors enforce source equality.
                    chapter.write_text(originals[chapter].replace(before, after))
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
                if source == helper:
                    assert call(form_for('LeanRunGate.Helper.twice'), value) == oracle(role, value)
                record('implementation invalidation '+role, program=changed_plan['programs']['LeanRunGate.Chapter']['LeanRunGate.greet']['manifest'])
                source.write_text(originals[source])
                chapter.write_text(originals[chapter])

            # Redirect the stock resource library program Module to a real but different module.
            # The carrier still builds; publication must reject the missing Chapter bundle.
            wrong = originals[lakefile].replace(
                '`+LeanRunGate.Chapter:virResourcePack',
                '`+LeanRunBlog.Page:virResourcePack')
            lakefile.write_text(wrong)
            carrier.write_text(originals[carrier].replace("#[LeanRunGate.Chapter]", "#[LeanRunBlog.Page]"))
            command(['lake','build'],'wrong-root-build')
            for destination in [site, OUTPUT/'wrong-root']:
                failed=command(['lake','exe','lean-run-demo','--output',str(destination)],
                    'wrong-root-'+destination.name,expected=1)
                assert 'LeanRunGate.Chapter:' in failed and 'LeanRunGate.greet' in failed
                assert 'no published program bundle' in failed and '+Module:virResourcePack' in failed and ':virResourcePack' in failed and 'include_vir_assets' in failed
            assert (site/'html-multi/lean-run/publication.json').read_bytes() == published_before
            assert not (OUTPUT/'wrong-root/html-multi/lean-run/publication.json').exists()
            lakefile.write_text(originals[lakefile])
            carrier.write_text(originals[carrier])
            command(['lake','build'],'restore-root-build')
            record('wrong stock producer registration rejects publication and preserves the accepted site')

            for destination in [site, OUTPUT/'conflicting-bundles']:
                failed=command(['lake','exe','lean-run-publication-check','conflict','--output',str(destination)],
                    'conflicting-bundles-'+destination.name,expected=1)
                assert 'LOGICAL_ID_CONFLICT' in failed and 'LeanRunGate.Chapter' in failed
            assert (site/'html-multi/lean-run/publication.json').read_bytes() == published_before
            assert not (OUTPUT/'conflicting-bundles/html-multi/lean-run/publication.json').exists()
            record('forSite rejects distinct valid same-module bundles with LOGICAL_ID_CONFLICT before writing')

            # Change source and build roots without changing the explicit module include.
            # No prepared pack is moved to the new root: its prerequisite repairs it.
            moved.parent.mkdir(exist_ok=True)
            assert not moved.exists()
            resources.rename(moved)
            staged=moved/'.vir-generated'
            if staged.exists():
                staged.rename(Path(tempfile.mkdtemp(prefix='old-prepared-', dir=moved.parent))/'packs')
            layout=originals[lakefile].replace('package verso_run\n',
                'package verso_run where\n  buildDir := ".lake/registration-build"\n')
            layout=layout.replace('srcDir := "demo/resources"', 'srcDir := "_registration-layout/resources"')
            lakefile.write_text(layout)
            command(['lake','build'],'custom-carrier-layout-build')
            changed=OUTPUT/'custom-carrier-layout'
            generate(changed)
            changed_plan=json.loads((changed/'html-single/lean-run/publication.json').read_text())
            assert changed_plan == plan
            assert (ROOT/'.lake/registration-build/lib/lean/vir-assets/LeanRunGate/Chapter.virres').is_file()
            shutil.copytree(changed/'html-single',server_root/'custom-carrier-layout',dirs_exist_ok=True)
            page.goto(base+'custom-carrier-layout/')
            page.wait_for_selector('.lean-run[data-enhanced]')
            assert call(form_for('LeanRunGate.greet'),'module assets') == oracle('greet','module assets')
            record('module-owned assets survive custom source/build roots with identical browser publication')
        finally:
            if moved.exists(): moved.rename(resources)
            for source, text in originals.items(): source.write_text(text)
            command(['lake','build'],'restore-build')
            generate(site)
        restored=json.loads((site/'html-multi/lean-run/publication.json').read_text())
        assert restored == plan
        record('restored program identity matches original')
    browser.close()
server.shutdown()
command([sys.executable, 'tests/blog.py', '--output', str(OUTPUT/'blog')], 'blog-adapter')
record('Blog Page/Post generation, draft policy, and actual worker qualification')
command([sys.executable, 'tests/slides.py', '--output', str(OUTPUT/'slides')], 'slides-adapter')
record('Slides native publication, fragment lifecycle, and actual worker qualification')
command([sys.executable, 'tests/typed-forms.py', '--output', str(OUTPUT/'typed')], 'typed-forms')
record('Bool/UInt64/multiline native signatures, shared codec, and all genre controls')
command([sys.executable, 'tests/inline-genres.py', '--output', str(OUTPUT/'inline')], 'inline-genres')
record('inline Page/Post/Slides authoring, retained scopes, native source and actual workers')
(OUTPUT/'results.json').write_text(json.dumps(dict(checks=results,publication=plan),ensure_ascii=False,indent=2)+'\n')
print(f'{len(results)} checks passed; evidence: {OUTPUT}',flush=True)
