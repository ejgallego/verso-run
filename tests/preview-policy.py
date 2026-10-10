"""Exercise raw markup through the actual compiled Html and sequence presenters."""
import argparse, json, shutil
from pathlib import Path
from playwright.sync_api import sync_playwright
from harness import serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--site', required=True)
parser.add_argument('--output', default='_out/preview-policy')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []

with serve_directory(Path(args.site).resolve()) as base, sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    requests = []
    def external(route):
        requests.append(route.request.url)
        route.fulfill(body='external resource')
    page.route('**/preview-external-*', external)
    page.goto(base+'Greeting/')
    page.wait_for_selector('.lean-run[data-enhanced]')
    markup = f'''<p id="benign">Raw Html remains visible</p>
        <script>parent.postMessage("preview-script", "*")</script>
        <img src="{base}preview-external-image" onerror="parent.postMessage('preview-event', '*')">
        <svg onload="parent.postMessage('preview-event', '*')"></svg>
        <link rel="stylesheet" href="{base}preview-external-style">
        <style>@import url('{base}preview-external-import');</style>
        <iframe src="{base}preview-external-frame"></iframe>
        <a id="escape" target="_top" href="{base}preview-external-navigation">Escape</a>
        <form action="{base}preview-external-form"><button id="submit">Submit</button></form>'''
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    for kind in ['html', 'sequence', 'automaton']:
        await_result = page.evaluate('''async ({kind, markup}) => {
            globalThis.previewMessages = [];
            globalThis.observePreview ??= event => {
                if (String(event.data).startsWith('preview-')) previewMessages.push(event.data);
            };
            addEventListener('message', observePreview);
            const {ViewHost} = await import(new URL('../lean-run/presenter.js', location.href));
            const root = document.createElement(kind === 'html' ? 'iframe' : 'div');
            root.id = 'policy-preview';
            // Keep real clicks clear of the Manual's fixed navigation.
            root.style.cssText = 'position:fixed;top:20px;left:20px;width:760px;height:600px;z-index:2147483647;background:white;overflow:auto';
            if (kind === 'html') { root.setAttribute('sandbox', ''); root.referrerPolicy = 'no-referrer'; }
            document.body.append(root);
            globalThis.policyView = new ViewHost(root, kind, error => { throw error; });
            const frame = {label: '<img src=x onerror=alert(1)>', html: markup,
                    error: '<script>alert(1)</script>'};
            return await policyView.show(kind === 'html' ? markup : kind === 'automaton' ? frame : {
                version: 1n, frames: [frame]});
        }''', {'kind': kind, 'markup': markup})
        assert await_result is True
        frame = page.locator('#policy-preview' if kind == 'html' else '#policy-preview iframe')
        assert frame.get_attribute('sandbox') == ''
        inside = page.frame_locator('#policy-preview' if kind == 'html' else '#policy-preview iframe')
        assert inside.locator('#benign').inner_text() == 'Raw Html remains visible'
        if kind != 'html':
            assert page.locator('#policy-preview .lean-run-sequence-strip img').count() == 0
            assert page.locator('#policy-preview .lean-run-sequence-error script').count() == 0
        checks.append(kind+': raw markup renders; control labels and errors remain text')
        page.wait_for_timeout(100)
        assert page.evaluate('previewMessages') == []
        assert requests == [], requests
        checks.append(kind+': scripts, event handlers and external embedded resources are blocked')
        original = page.url
        inside.locator('#escape').click()
        inside.locator('#submit').click()
        page.wait_for_timeout(100)
        assert page.url == original
        assert requests == [], requests
        checks.append(kind+': top navigation and form submission are blocked')
        page.evaluate('policyView.clear()')
        assert page.locator('#policy-preview').is_hidden()
        if kind == 'html': assert frame.get_attribute('srcdoc') is None
        else: assert page.locator('#policy-preview iframe').count() == 0
        page.evaluate('document.querySelector("#policy-preview").remove()')
        checks.append(kind+': clearing removes the old preview and disposes its presenter')
    assert not errors, errors
    browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks}, indent=2)+'\n')
print(f'{len(checks)} raw preview policy checks passed', flush=True)
