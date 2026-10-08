"""Landing and Manual/Blog native agreement on an actual HTTP deployment."""
import argparse
import atexit
import functools
import http.server
import json
from pathlib import Path
import shutil
import subprocess
import threading
from urllib.request import urlopen
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--url', default='https://ejgallego.github.io/verso-run/')
parser.add_argument('--site', help='serve a local generated site instead of the hosted URL')
parser.add_argument('--output', default='_out/pages-smoke.json')
args = parser.parse_args()
base = args.url.rstrip('/') + '/'
if args.site:
    class QuietHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_): pass
        def handle(self):
            try:
                super().handle()
            except (BrokenPipeError, ConnectionResetError):
                pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0),
        functools.partial(QuietHandler, directory=str((root / args.site).resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    atexit.register(server.server_close)
    atexit.register(server.shutdown)
    base = f'http://127.0.0.1:{server.server_port}/'
plans = {}
for genre, path in [('Manual', ''), ('Blog', 'blog/')]:
    with urlopen(base + path + 'lean-run/publication.json') as response:
        plans[genre] = json.load(response)
    assert plans[genre] == json.loads((root / '_out/html-multi' / path / 'lean-run/publication.json').read_text())
plan = plans['Manual']
checks = ['Manual and Blog publications match validated local programs and runtime']

def oracle(role, value, genre):
    executable = 'lean-run-blog-oracle' if genre == 'Blog' else 'lean-run-oracle'
    return json.loads(subprocess.check_output(
        [str(root / '.lake/build/bin' / executable), role, value], text=True))

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    errors = []
    runtime_responses = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('response', lambda response: runtime_responses.append({
        'url': response.url, 'contentType': response.headers.get('content-type', ''),
        'status': response.status}) if plan['runtimeModule'].rsplit('/', 1)[0] in response.url else None)
    response = page.goto(base)
    assert response.status == 200
    for label, path in [
        ('Explore the manual', 'Greeting/'),
        ('see its source anchors', 'Anchored-source/'),
        ('Try a runnable page', 'blog/page/'),
        ('read the runnable post', 'blog/notes/2026-10-8-running-lean-in-a-post/'),
    ]:
        link = page.get_by_role('link', name=label, exact=True)
        assert link.evaluate('(e) => e.href') == base + path
    assert page.get_by_role('heading', name='Slides', exact=True).count() == 1
    assert 'Slide support is planned' in page.locator('body').inner_text()
    for width in [1280, 390]:
        page.set_viewport_size({'width': width, 'height': 900})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(root / f'_out/landing-{width}.png'), full_page=True)
    checks.append('landing links resolve to Manual and Blog; Slides is marked planned; both viewports fit')
    for path, declaration, role, value, genre in [
        ('Greeting/', 'LeanRunGate.greet', 'greet', '世界 🌍', 'Manual'),
        ('Exact-natural-numbers/', 'LeanRunGate.double', 'double', '9007199254740993', 'Manual'),
        ('HTML-greeting/', 'LeanRunGate.htmlGreeting.leanRunHtml', 'htmlGreeting', '<b>& Ada', 'Manual'),
        ('Illuminate-diagrams/', 'LeanRunGate.diagram.leanRunHtml', 'diagram', '6', 'Manual'),
        ('blog/page/', 'LeanRunGate.Helper.twice', 'twice', '9007199254740993', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.greet', 'greet', '世界 🌍', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.card', 'card', '<b>& Ada', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.count', 'count', '11', 'Blog'),
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
        expected = oracle(role, value, genre)
        if role not in ['htmlGreeting', 'diagram', 'card']:
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

result = {'url': base, 'checks': checks, 'publication': plan, 'blogPublication': plans['Blog'], 'runtimeResponses': runtime_responses}
(root / args.output).write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'url': base, 'checks': checks}, indent=2, ensure_ascii=False))
