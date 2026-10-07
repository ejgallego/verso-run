"""Actual Pages/native agreement. Adapted from the VIR integration handoff's
source-inspected hosted-smoke-reference.py; this retains its four hosted checks."""
import json
from pathlib import Path
import shutil
import subprocess
from urllib.request import urlopen
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
base = 'https://ejgallego.github.io/verso-run/'
with urlopen(base + 'lean-run/publication.json') as response:
    plan = json.load(response)
assert plan == json.loads((root / '_out/html-multi/lean-run/publication.json').read_text())
checks = ['hosted publication matches validated local program and runtime']

def oracle(role, value):
    return json.loads(subprocess.check_output(
        [str(root / '.lake/build/bin/lean-run-oracle'), role, value], text=True))

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    errors = []
    runtime_responses = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('response', lambda response: runtime_responses.append({
        'url': response.url, 'contentType': response.headers.get('content-type', ''),
        'status': response.status}) if plan['runtimeModule'].rsplit('/', 1)[0] in response.url else None)
    for path, declaration, role, value in [
        ('Greeting/', 'LeanRunGate.greet', 'greet', '世界 🌍'),
        ('Exact-natural-numbers/', 'LeanRunGate.double', 'double', '9007199254740993'),
        ('HTML-greeting/', 'LeanRunGate.htmlGreeting.leanRunHtml', 'htmlGreeting', '<b>& Ada'),
        ('Illuminate-diagrams/', 'LeanRunGate.diagram.leanRunHtml', 'diagram', '6'),
    ]:
        response = page.goto(base + path)
        assert response.status == 200, (path, response.status)
        page.wait_for_selector('.lean-run[data-enhanced]')
        form = page.locator('.lean-run[data-experiment*="' + declaration + '"]').first
        form.locator('input').fill(value)
        form.locator('[type=submit]').click()
        page.wait_for_function("e => ['success', 'failed'].includes(e.dataset.state)",
                               arg=form.element_handle(), timeout=60000)
        assert form.get_attribute('data-state') == 'success', form.inner_text()
        expected = oracle(role, value)
        if role in ['greet', 'double']:
            assert form.locator('.lean-run-output').text_content() == expected
        else:
            frame = form.locator('iframe')
            assert expected in frame.get_attribute('srcdoc')
            assert frame.get_attribute('sandbox') == ''
            if role == 'diagram':
                assert form.frame_locator('iframe').locator('svg text').count() == 6
            else:
                assert '&lt;b&gt;&amp; Ada' in frame.get_attribute('srcdoc')
                assert form.frame_locator('iframe').locator('b').count() == 0
        checks.append(f'{path}: edited input executes through the hosted worker and matches native Lean')
    assert not errors, errors
    checks.append('no uncaught browser errors')
    browser.close()

result = {'url': base, 'checks': checks, 'publication': plan, 'runtimeResponses': runtime_responses}
(root / '_out/pages-smoke.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'url': base, 'checks': checks}, indent=2, ensure_ascii=False))
