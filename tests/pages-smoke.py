"""Landing and Manual/Blog native agreement on an actual HTTP deployment."""
import argparse
import atexit
import functools
import http.server
import hashlib
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
parser.add_argument('--revision', help='require the immutable deployed source revision and a clean build')
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
with urlopen(base + 'verso-run-build.json') as response:
    build_identity = json.load(response)
if args.revision:
    assert build_identity['source'] == args.revision, build_identity
    assert build_identity['dirty'] is False, build_identity
local_manifest = json.loads((root / 'lake-manifest.json').read_text())
assert build_identity['dependencies'] == {p['name']: p['rev'] for p in local_manifest['packages']}
assert build_identity['runtime'] == '6cddc4b897410d7524a69bdaff0327d9f07916735078a0b12d548e2f88c23d20'
plans = {}
for genre, path in [('Manual', ''), ('Blog', 'blog/'), ('Slides', 'slides/')]:
    with urlopen(base + path + 'lean-run/publication.json') as response:
        plans[genre] = json.load(response)
    assert plans[genre] == json.loads((root / '_out/html-multi' / path / 'lean-run/publication.json').read_text())
shared_hashes = {}
for genre, path in [('Manual', ''), ('Blog', 'blog/'), ('Slides', 'slides/')]:
    shared_hashes[genre] = {}
    for name in ['host.js', 'worker.js', 'contract.js', 'renderer.js', 'sequence.js']:
        with urlopen(base + path + 'lean-run/' + name) as response:
            contents = response.read()
        assert contents == (root / '_out/html-multi' / path / 'lean-run' / name).read_bytes(), (genre, name)
        shared_hashes[genre][name] = hashlib.sha256(contents).hexdigest()
plan = plans['Manual']
checks = ['Manual, Blog, and Slides publications match validated local programs and runtime',
          'all three genres serve the exact accepted host, worker, codec, renderer and sequence bridge bytes']

def oracle(role, value, genre):
    executable = 'lean-run-blog-oracle' if genre in ['Blog', 'Slides'] else 'lean-run-oracle'
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
        'status': response.status}) if any(
            p['runtimeModule'].rsplit('/', 1)[0] in response.url for p in plans.values()) else None)
    response = page.goto(base)
    assert response.status == 200
    for label, path in [
        ('Explore the manual', 'Greeting/'),
        ('see its source anchors', 'Anchored-source/'),
        ('Try a runnable page', 'blog/page/'),
        ('read the runnable post', 'blog/notes/2026-10-8-running-lean-in-a-post/'),
        ('Try the runnable slides', 'slides/'),
    ]:
        link = page.get_by_role('link', name=label, exact=True)
        assert link.evaluate('(e) => e.href') == base + path
    assert page.get_by_role('heading', name='Slides', exact=True).count() == 1
    for width in [1280, 390]:
        page.set_viewport_size({'width': width, 'height': 900})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(root / f'_out/landing-{width}.png'), full_page=True)
    checks.append('landing links resolve to all three genres; both viewports fit')
    for path, declaration, role, value, genre in [
        ('Greeting/', 'LeanRunGate.greet', 'greet', '世界 🌍', 'Manual'),
        ('Exact-natural-numbers/', 'LeanRunGate.double', 'double', '9007199254740993', 'Manual'),
        ('HTML-greeting/', 'LeanRunGate.htmlGreeting.leanRunHtml', 'htmlGreeting', '<b>& Ada', 'Manual'),
        ('Illuminate-diagrams/', 'LeanRunGate.diagram.leanRunHtml', 'diagram', '6', 'Manual'),
        ('blog/page/', 'LeanRunGate.Helper.twice', 'twice', '9007199254740993', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.greet', 'greet', '世界 🌍', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.card', 'card', '<b>& Ada', 'Blog'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.count', 'count', '11', 'Blog'),
        ('slides/', 'LeanRunGate.Helper.twice', 'twice', '9007199254740993', 'Slides'),
        ('slides/', 'LeanRunBlog.Examples.greet', 'greet', '世界 🌍', 'Slides'),
        ('slides/', 'LeanRunBlog.Examples.card', 'card', '<b>& Ada', 'Slides'),
        ('slides/', 'LeanRunBlog.Examples.count', 'count', '11', 'Slides'),
    ]:
        print(f'CHECK {genre} {path} {role}', flush=True)
        response = page.goto(base + path)
        assert response.status == 200, (path, response.status)
        page.wait_for_selector('.lean-run[data-enhanced]')
        if genre == 'Slides':
            page.wait_for_function('globalThis.Reveal?.isReady() && globalThis.versoVirState === "ready"')
            page.evaluate('document.fonts.ready')
            page.wait_for_function('!Reveal.getViewportElement().classList.contains("loading-scroll-mode")')
            index = {'twice': 0, 'greet': 1, 'count': 2, 'card': 3}[role]
            page.evaluate('(n) => Reveal.slide(n, 0)', index)
            if page.evaluate('Reveal.isScrollView()'):
                # Scroll-mode slide() can stop at the preceding snap boundary.
                # Advance with the public navigation API, as a reader would.
                for _ in range(6):
                    page.wait_for_timeout(100)
                    current = page.evaluate('Reveal.getIndices().h')
                    if current == index: break
                    page.evaluate('Reveal.next()' if current < index else 'Reveal.prev()')
            page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)
            if role == 'greet':
                page.evaluate('Reveal.nextFragment()')
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
    # Qualify the new bounded controls and inline functions on the actual deployment.
    page.set_viewport_size({'width': 1280, 'height': 1000})
    for genre, path, owner in [
        ('Manual', '', 'LeanRunGate.Chapter'),
        ('Blog', 'blog/page/', 'LeanRunBlog.Page'),
        ('Slides', 'slides/', 'LeanRunSlides.Deck')]:
        for role, values in [('flip', ['false', 'true']),
                             ('increment', ['9007199254740993', '18446744073709551615']),
                             ('lines', [' a \n世界 🌍\n\n<b>&\n'])]:
            location = path if genre != 'Manual' else ('Multiline-text/' if role == 'lines' else 'Typed-inputs/')
            page.goto(base + location)
            page.wait_for_selector('.lean-run[data-enhanced]')
            if genre == 'Slides':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                index = {'flip': 4, 'increment': 5, 'lines': 6}[role]
                page.evaluate('(n) => Reveal.slide(n, 0)', index)
                page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)
            form = page.locator('.lean-run[data-experiment*="LeanRunTyped.Examples.' + role + '"]').first
            for value in values:
                field = form.locator('input, select, textarea')
                if role == 'flip': field.select_option(value)
                else: field.fill(value)
                form.locator('[type=submit]').click()
                page.wait_for_function("e => ['success', 'failed'].includes(e.dataset.state)",
                                       arg=form.element_handle(), timeout=60000)
                assert form.get_attribute('data-state') == 'success', form.inner_text()
                expected = json.loads(subprocess.check_output(
                    [str(root / '.lake/build/bin/lean-run-typed-oracle'), role, value], text=True))
                assert form.locator('.lean-run-output').text_content() == expected
            checks.append(genre + ': hosted ' + role + ' control agrees with native Lean')
    for path, owner, role in [
        ('blog/page/', 'LeanRunBlog.Page', 'page'),
        ('blog/notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Post', 'post'),
        ('slides/', 'LeanRunSlides.Deck', 'slide')]:
        for function in ['greet', 'card']:
            page.goto(base + path)
            page.wait_for_selector('.lean-run[data-enhanced]')
            if role == 'slide':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                index = 7 if function == 'greet' else 9
                page.evaluate('(n) => Reveal.slide(n, 0)', index)
                page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)
                if function == 'greet': page.evaluate('Reveal.nextFragment()')
            form = page.locator('.lean-run[data-experiment*="' + owner + '.Inline.' + function + '"]').first
            value = '世界 🌍 <b>&'
            form.locator('input').fill(value)
            form.locator('[type=submit]').click()
            page.wait_for_function("e => ['success', 'failed'].includes(e.dataset.state)",
                                   arg=form.element_handle(), timeout=60000)
            assert form.get_attribute('data-state') == 'success', form.inner_text()
            expected = oracle(role + ('InlineGreet' if function == 'greet' else 'InlineCard'), value, 'Blog')
            if function == 'greet':
                assert form.locator('.lean-run-output').text_content() == expected
            else:
                assert expected in form.locator('iframe').get_attribute('srcdoc')
                assert form.locator('iframe').get_attribute('sandbox') == ''
                assert form.frame_locator('iframe').locator('b').count() == 0
            checks.append(path + ': hosted inline ' + function + ' agrees with native Lean')
    # Selection and view rendering run in the Lean DOM presenter, independently
    # of the pure worker computation. Compare every displayed frame to Lean.
    for genre, path in [('Manual', 'Stack-stepper/'), ('Blog', 'blog/page/'),
                        ('Blog', 'blog/notes/2026-10-8-running-lean-in-a-post/'),
                        ('Slides', 'slides/')]:
        page.goto(base + path)
        page.wait_for_selector('.lean-run[data-enhanced]')
        if genre == 'Slides':
            page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
            page.evaluate('Reveal.slide(10, 0)')
            page.wait_for_function('Reveal.getIndices().h === 10')
        form = page.locator('.lean-run[data-experiment*="LeanRunSequence.Examples.stackView"]')
        value = '9007199254740993 2 *'
        form.locator('input[type=text]').fill(value)
        form.locator('[type=submit]').click()
        page.wait_for_function("e => ['success', 'failed'].includes(e.dataset.state)",
                               arg=form.element_handle(), timeout=60000)
        assert form.get_attribute('data-state') == 'success', form.inner_text()
        expected = json.loads(oracle('sequence', value, 'Manual'))
        for index, frame in enumerate(expected['frames']):
            form.locator(f'[data-step="{index}"]').click()
            assert frame['html'] in form.locator('iframe').get_attribute('srcdoc')
            assert form.locator('iframe').get_attribute('sandbox') == ''
            assert form.locator('.lean-run-sequence-error').text_content() == (frame['error'] or '')
            assert form.locator('.lean-run-sequence-position').text_content() == (
                f"Step {index + 1} of {len(expected['frames'])}: {frame['label']}")
        checks.append(path + ': Lean DOM selection displays every exact native sequence frame')
    assert not errors, errors
    checks.append('no uncaught browser errors')
    browser.close()

result = {'sharedHostHashes': shared_hashes, 'build': build_identity, 'url': base, 'checks': checks, 'publication': plan, 'blogPublication': plans['Blog'],
          'slidesPublication': plans['Slides'], 'runtimeResponses': runtime_responses}
(root / args.output).write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'url': base, 'checks': checks}, indent=2, ensure_ascii=False))
