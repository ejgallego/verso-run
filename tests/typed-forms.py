"""Concrete Bool/UInt64/multiline forms, independently compiled signatures and real workers."""
from harness import run_command, serve_directory
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/typed-forms')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []
command = functools.partial(run_command, output=output, cwd=ROOT)

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


def oracle(role, value):
    return json.loads(subprocess.check_output(
        [str(ROOT/'.lake/build/bin/lean-run-typed-oracle'), role, value], text=True))

command(['node', 'tests/typed-codec.mjs'], 'codec')
record('shared input/result codec checks exact Bool, UInt64 bounds and untrimmed String')
site = output/'site'
command(['lake', 'exe', 'lean-run-demo', '--output', str(site/'manual'), '--with-html-single', '--with-tex', '--depth', '2'], 'manual')
command(['lake', 'exe', 'lean-run-blog-demo', '--output', str(site/'blog')], 'blog')
command(['lake', 'exe', 'lean-run-slides-demo', '--output', str(site/'slides')], 'slides')
plans = {}
for genre, path, owner in [('Manual', site/'manual/html-multi', 'LeanRunGate.Chapter'),
                           ('Blog', site/'blog', 'LeanRunBlog.Page'),
                           ('Slides', site/'slides', 'LeanRunSlides.Deck')]:
    plan = json.loads((path/'lean-run/publication.json').read_text())
    plans[genre] = plan
    for role, name, tag in [('flip', 'Bool', 2), ('increment', 'UInt64', 7), ('lines', 'String', 3)]:
        binding = plan['programs'][owner]['LeanRunTyped.Examples.'+role]
        descriptor = {'type': name, 'interfaceTag': tag}
        assert binding['expectedExport'] == {'args': [descriptor], 'result': descriptor, 'effect': 'pure'}
    record(genre+': independent type-only canonical Bool/UInt64/String signatures')


served = output/'served'
for genre, path in [('manual', site/'manual/html-multi'), ('blog', site/'blog'), ('slides', site/'slides')]:
    for prefix in ['root', 'nested/prefix']:
        shutil.copytree(path, served/prefix/genre, dirs_exist_ok=True)
shutil.copytree(site/'manual/html-single', served/'single', dirs_exist_ok=True)
with serve_directory(served) as base:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width': 1280, 'height': 1000})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))

        def form(role):
            return page.locator('.lean-run[data-experiment*="LeanRunTyped.Examples.'+role+'"]').first

        def wait_success(selected):
            page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                                   arg=selected.element_handle(), timeout=30000)
            assert selected.get_attribute('data-state') == 'success', selected.inner_text()
            return selected.locator('.lean-run-output').text_content()

        def call(role, value, shortcut=False):
            selected = form(role)
            field = selected.locator('input, select, textarea')
            if role == 'flip': field.select_option(value)
            else: field.fill(value)
            if shortcut: field.press('Control+Enter')
            else: selected.locator('[type=submit]').click()
            return wait_success(selected)

        def visit(prefix, genre, role):
            path = {'manual': ('Typed-inputs/' if role != 'lines' else 'Multiline-text/'),
                    'blog': 'page/', 'slides': ''}[genre]
            page.goto(base+prefix+'/'+genre+'/'+path)
            page.wait_for_selector('.lean-run[data-enhanced]')
            selected = form(role)
            description = json.loads(selected.get_attribute('data-experiment'))
            assert description['declaration'] == 'LeanRunTyped.Examples.'+role
            assert description['producerModule'] == description['program']
            assert description['callable'].startswith(description['program']+'.')
            assert description['callable'].endswith('.'+role+'.leanRun')
            assert description['form'] == {'flip': 'bool', 'increment': 'uint64', 'lines': 'multilineString'}[role]
            assert not {'shape', 'output', 'multiline', 'signature'} & description.keys()
            assert '@[vir_export]' not in selected.locator('.lean-run-source').text_content()
            if genre == 'slides':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                index = {'flip': 4, 'increment': 5, 'lines': 6}[role]
                page.evaluate('(n) => Reveal.slide(n, 0)', index)
                page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)

        for prefix in ['root', 'nested/prefix']:
            for genre in ['manual', 'blog', 'slides']:
                visit(prefix, genre, 'flip')
                assert form('flip').locator('select').input_value() == 'false'
                for value in ['false', 'true', 'false']:
                    assert call('flip', value) == oracle('flip', value)
                record(prefix+'/'+genre+': Boolean selector transports actual false/true with native results')
                visit(prefix, genre, 'increment')
                for value in ['0', '00001', '9007199254740993', '18446744073709551614', '18446744073709551615']:
                    assert call('increment', value) == oracle('increment', value)
                selected = form('increment')
                worker_count = len(page.workers)
                for value in ['18446744073709551616', '-1', '+1', '1e3', '0x10', '1.0', '', ' 1', '1 ']:
                    selected.locator('input').fill(value)
                    selected.locator('[type=submit]').click()
                    assert selected.get_attribute('data-state') == 'invalid input', value
                    assert len(page.workers) <= worker_count
                assert call('increment', '41') == oracle('increment', '41')
                record(prefix+'/'+genre+': UInt64 exact large/max/wrap values and invalid-input recovery')
                visit(prefix, genre, 'lines')
                textarea = form('lines').locator('textarea')
                assert textarea.input_value() == 'Hello\nLean'
                textarea.fill('first')
                textarea.press('End')
                textarea.press('Enter')
                assert textarea.input_value() == 'first\n'
                assert form('lines').get_attribute('data-state') == 'idle'
                if genre == 'slides': assert page.evaluate('Reveal.getIndices().h') == 6
                for value in ['', '\n', '\nα 🌍\n\n<b>&\n', ' a \n b ', 'x'*4096]:
                    assert call('lines', value, shortcut=True) == oracle('lines', value)
                    assert form('lines').locator('.lean-run-output b').count() == 0
                record(prefix+'/'+genre+': multiline whitespace/Unicode survives; Enter edits and Ctrl+Enter runs')

        # Two controls on one Blog page keep their host state independent.
        visit('root', 'blog', 'flip')
        assert call('flip', 'false') == 'true'
        assert call('increment', '9007199254740993') == oracle('increment', '9007199254740993')
        assert form('flip').locator('.lean-run-output').text_content() == 'true'
        assert len({form(role).get_attribute('data-instance') for role in ['flip', 'increment', 'lines']}) == 3
        record('different typed controls keep independent worker state on one page')
        # Independent expectations must reject a wrong compiler-facing type before call.
        for role, wrong_type, wrong_tag in [('flip', 'Nat', 0), ('increment', 'Nat', 0)]:
            original = plans['Blog']
            bad = json.loads(json.dumps(original))
            bad['programs']['LeanRunBlog.Page']['LeanRunTyped.Examples.'+role]['expectedExport']['result'] = {
                'type': wrong_type, 'interfaceTag': wrong_tag}
            page.route('**/lean-run/publication.json', lambda route, request, data=bad: route.fulfill(
                content_type='application/json', body=json.dumps(data)))
            visit('root', 'blog', role)
            selected = form(role)
            selected.locator('[type=submit]').click()
            page.wait_for_function('e => e.dataset.state === "failed"', arg=selected.element_handle(), timeout=30000)
            assert 'does not match expected callable signature' in selected.locator('.lean-run-output').text_content().lower()
            page.unroute('**/lean-run/publication.json')
            record(role+': independently wrong result expectation rejects before invocation')

        visit('root', 'blog', 'lines')
        assert call('lines', 'desktop\ntext') == oracle('lines', 'desktop\ntext')
        page.screenshot(path=str(output/'typed-desktop.png'), full_page=True)
        page.set_viewport_size({'width': 390, 'height': 900})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(output/'typed-mobile.png'), full_page=True)
        record('typed selectors, decimal fields and multiline controls fit narrow output')
        plain = browser.new_context(java_script_enabled=False)
        tab = plain.new_page()
        for genre, path in [('manual', 'Multiline-text/'), ('blog', 'page/'), ('slides', '')]:
            tab.goto(base+'root/'+genre+'/'+path)
            textarea = tab.locator('.lean-run[data-experiment*="LeanRunTyped.Examples.lines"]')
            assert textarea.locator('textarea').input_value() == 'Hello\nLean'
            assert textarea.locator('textarea').is_visible()
            assert textarea.locator('[type=submit]').is_disabled()
        plain.close()
        record('all genres preserve multiline presets and readable source without JavaScript')
        page.goto(base+'single/')
        page.wait_for_selector('.lean-run[data-enhanced]')
        assert call('flip', 'true') == 'false'
        assert call('increment', '18446744073709551615') == '0'
        assert call('lines', '\nlast\n') == oracle('lines', '\nlast\n')
        tex = next((site/'manual/tex').rglob('*.tex')).read_text()
        assert 'LeanRunTyped' in tex
        record('Manual single HTML and TeX retain typed examples')
        assert not errors, errors
        record('no uncaught typed-form browser errors')
        browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks, 'publications': plans}, indent=2)+'\n')
print(f'{len(checks)} typed form checks passed; evidence: {output}', flush=True)
