"""Verso guide links, checked content, publication and real workers after relocation."""
import argparse
import functools
import json
from html.parser import HTMLParser
from pathlib import Path
import shutil
from urllib.parse import unquote, urljoin, urlsplit

from playwright.sync_api import sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--site', help='combined site containing guide/ and api/')
parser.add_argument('--output', default='_out/user-guide-acceptance')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
command = functools.partial(run_command, output=output, cwd=ROOT)
checks = []


def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


if args.site:
    site = (ROOT / args.site).resolve()
else:
    command(['python3', 'scripts/build-user-guide.py'], 'generate')
    command(['python3', 'scripts/build-api-reference.py'], 'reference')
    site = output / 'site'
    for source, target in [(ROOT / '_out/guide/html-multi', site / 'guide'),
                           (ROOT / '.lake/build/literate-html', site / 'api')]:
        shutil.copytree(source, target, dirs_exist_ok=True)

guide = site / 'guide'
expected = {'index.html', 'find/index.html', 'search/index.html', *[
    name + '/index.html' for name in ['authoring', 'blog', 'slides', 'hosting', 'troubleshooting']]}
assert {str(p.relative_to(guide)) for p in guide.rglob('index.html')} == expected
plan = json.loads((guide / 'lean-run/publication.json').read_text())
assert set(plan['programs']) == {'VersoRunGuide.Authoring'}
assert set(plan['programs']['VersoRunGuide.Authoring']) == {'Demo.greet', 'Demo.card'}
record('dedicated Verso manual publishes five guide chapters and its own example programs')


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.base = ''
        self.links = []
        self.ids = set()
        self.feed(path.read_text())

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == 'base': self.base = attributes.get('href', '')
        if tag == 'a' and 'href' in attributes: self.links.append(attributes['href'])
        if 'id' in attributes: self.ids.add(attributes['id'])


parsed = {}
for path in guide.rglob('*.html'):
    parsed[path] = Page(path)
for path, page in parsed.items():
    current = 'https://guide.invalid/' + str(path.relative_to(site))
    base = urljoin(current, page.base)
    for link in page.links:
        target = urlsplit(urljoin(base, link))
        if target.netloc != 'guide.invalid': continue
        relative = unquote(target.path).lstrip('/')
        # The standalone guide check has no demo homepage. The complete
        # package checks that link through pages-smoke.py.
        if relative == '' and not args.site: continue
        file = site / relative
        if file.is_dir() or target.path.endswith('/'): file /= 'index.html'
        assert file.is_relative_to(site) and file.is_file(), (path, link, file)
        if target.fragment and file in parsed and 'find/' not in str(file.relative_to(guide)):
            assert unquote(target.fragment) in parsed[file].ids, (path, link)
record('generated cross-chapter links and section anchors resolve; API reference is adjacent')

served = output / 'served'
for prefix in ['root', 'nested/prefix']:
    shutil.copytree(site, served / prefix, dirs_exist_ok=True)
with serve_directory(served) as base, sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    for prefix in ['root', 'nested/prefix']:
        page.set_viewport_size({'width': 1280, 'height': 900})
        home = base + prefix + '/guide/'
        response = page.goto(home)
        assert response.status == 200
        page.get_by_role('link', name='a runnable block', exact=True).click()
        page.wait_for_url('**/authoring/**')
        for declaration, value in [('Demo.greet', 'Ada'), ('Demo.card', '<b>& Ada')]:
            form = page.locator('.lean-run[data-experiment*="' + declaration + '"]').first
            form.locator('input').fill(value)
            form.locator('[type=submit]').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)', arg=form.element_handle())
            assert form.get_attribute('data-state') == 'success', form.inner_text()
            if declaration == 'Demo.greet':
                assert form.locator('.lean-run-output').text_content() == 'Hello, Ada'
            else:
                preview = form.frame_locator('iframe')
                assert preview.locator('h2').inner_text() == 'Hello, <b>& Ada!'
                assert preview.locator('b').count() == 0
            if form.locator('.lean-run-stop').is_enabled():
                form.locator('.lean-run-stop').click()
        search = page.get_by_role('searchbox', name='Search', exact=True)
        page.wait_for_function('document.querySelector("#cb1-input")?.hasAttribute("aria-activedescendant")')
        search.press_sequentially('Publishing the document')
        result = page.locator('#cb1-listbox').get_by_role('option').filter(has_text='Publishing the document').first
        result.click()
        page.wait_for_url('**/*guide-authoring-publishing-the-document*')
        for chapter in ['authoring', 'blog', 'slides', 'hosting', 'troubleshooting']:
            page.goto(home + chapter + '/')
            for width in [1280, 390]:
                page.set_viewport_size({'width': width, 'height': 900})
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (prefix, chapter, width)
            if prefix == 'root':
                page.screenshot(path=str(output / (chapter + '-390.png')))
        record(prefix + ': navigation/search and compiled greeting/escaped Html work; all chapters fit desktop/phone')
    static = browser.new_context(java_script_enabled=False)
    static_page = static.new_page()
    static_page.goto(base + 'root/guide/authoring/')
    assert 'public def Demo.greet' in static_page.locator('main').inner_text()
    for button in static_page.locator('.lean-run [type=submit]').all():
        assert button.is_disabled()
    static.close()
    record('guide source remains readable with disabled Run controls when JavaScript is off')
    assert not errors, errors
    browser.close()
record('no uncaught guide browser errors')
(output / 'results.json').write_text(json.dumps({'checks': checks, 'publication': plan}, indent=2) + '\n')
print(f'{len(checks)} user guide checks passed; evidence: {output}', flush=True)
