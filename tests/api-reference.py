"""Generated view reference: selected modules, real links, search and relocation."""
import argparse
import functools
import hashlib
import json
import shutil
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

from playwright.sync_api import sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--site', help='check an already packaged reference')
parser.add_argument('--mutations', action='store_true')
parser.add_argument('--output', default='_out/api-reference-acceptance')
args = parser.parse_args()
if args.site and args.mutations:
    parser.error('mutation checks rebuild the reference; omit --site')
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)

if args.site:
    site = (ROOT / args.site).resolve()
else:
    command = functools.partial(run_command, output=output, cwd=ROOT)
    command(['python3', 'scripts/build-api-reference.py'], 'generate')
    site = ROOT / '.lake/build/literate-html'

modules = {'VersoLeanRun.' + name for name in ['Views', 'Frame', 'Sequence', 'Automaton']}
assert set((ROOT / '.lake/build/literate-plan').read_text().splitlines()) == modules
pages = sorted(site.rglob('index.html'))
assert {str(page.relative_to(site)) for page in pages} == {
    'index.html', 'search/index.html',
    *[name.replace('.', '/') + '/index.html' for name in modules]}
record('reference selects only the four public view modules, with a landing page and search')

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.base = ''
        self.links = []
        self.ids = set()
        self.text = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == 'base':
            self.base = attributes.get('href', '')
        if tag == 'a' and 'href' in attributes:
            self.links.append(attributes['href'])
        if 'id' in attributes:
            self.ids.add(attributes['id'])

    def handle_data(self, data):
        self.text.append(data)

if args.mutations:
    source = ROOT / 'src/views/VersoLeanRun/Views.lean'
    public = ROOT / '.lake/build/lib/lean/VersoLeanRun/Views.olean'
    original = source.read_text()
    original_hash = hashlib.sha256(public.read_bytes()).hexdigest()
    marker = 'Reference refresh probe.'
    try:
        source.write_text(original.replace('/-!\n', '/-!\n' + marker + '\n\n', 1))
        command(['python3', 'scripts/build-api-reference.py'], 'doc-edit')
        assert hashlib.sha256(public.read_bytes()).hexdigest() == original_hash
        assert marker in ''.join(Page(site / 'index.html').text)
    finally:
        source.write_text(original)
        command(['python3', 'scripts/build-api-reference.py'], 'doc-restore')
    assert marker not in ''.join(Page(site / 'index.html').text)
    record('documentation-only edits refresh HTML even with unchanged public olean; restoration refreshes it again')
    stylesheet = ROOT / 'docs/api-reference.css'
    original_css = stylesheet.read_text()
    css_marker = '/* Reference asset refresh probe. */'
    try:
        stylesheet.write_text(original_css + '\n' + css_marker + '\n')
        command(['python3', 'scripts/build-api-reference.py'], 'css-edit')
        assert css_marker in (site / stylesheet.name).read_text()
    finally:
        stylesheet.write_text(original_css)
        command(['python3', 'scripts/build-api-reference.py'], 'css-restore')
    assert (site / stylesheet.name).read_text() == original_css
    record('stylesheet-only edits refresh the copied asset and restoration removes the probe')

parsed = {path: Page(path) for path in pages}
for path, page in parsed.items():
    url = 'https://reference.invalid/' + str(path.relative_to(site))
    base = urljoin(url, page.base)
    for href in page.links:
        target = urlsplit(urljoin(base, href))
        if target.netloc != 'reference.invalid':
            continue
        destination = site / unquote(target.path).lstrip('/')
        if destination.is_dir():
            destination /= 'index.html'
        assert destination.is_file(), (path, href, destination)
        if target.fragment:
            assert unquote(target.fragment) in parsed[destination].ids, (path, href)
record('all generated local navigation and declaration links resolve to files and real anchors')

served = output / 'served'
for prefix in ['root/api', 'nested/docs/api']:
    shutil.copytree(site, served / prefix, dirs_exist_ok=True)
with serve_directory(served) as base, sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    errors = []
    failed_styles = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('response', lambda response: failed_styles.append(response.url)
            if response.request.resource_type == 'stylesheet' and
            (response.status not in [200, 304] or (response.status == 200 and
             'text/css' not in response.headers.get('content-type', ''))) else None)
    for prefix in ['root/api', 'nested/docs/api']:
        reference = base + prefix + '/'
        assert page.goto(reference).status == 200
        assert page.get_by_role('heading', name='Interactive Lean examples', exact=True).count() == 1
        for theme in ['light', 'dark']:
            page.emulate_media(color_scheme=theme, reduced_motion='reduce')
            styles = page.locator('.code-content > .mod-doc .hl.lean.block').first.evaluate('''block => {
                const s = getComputedStyle(block);
                const inline = document.querySelector('.hl.lean.inline');
                const link = inline.querySelector('a .const');
                return {
                    scrollable: s.overflowX === 'auto',
                    padding: parseFloat(s.paddingLeft) > parseFloat(getComputedStyle(inline).paddingLeft),
                    border: s.borderStyle === 'solid' && parseFloat(s.borderWidth) > 0,
                    plain: s.color === getComputedStyle(document.body).color,
                    keyword: getComputedStyle(block.querySelector('.keyword')).color !== s.color,
                    link: getComputedStyle(link).color !== getComputedStyle(document.body).color
                };
            }''')
            assert all(styles.values()), (prefix, theme, styles)
            page.screenshot(path=str(output / f'{prefix.replace("/", "-")}-{theme}.png'), full_page=True,
                            animations='disabled')
        page.emulate_media(color_scheme='light')
        for width in [1280, 390]:
            page.set_viewport_size({'width': width, 'height': 900})
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (prefix, width)
            page.screenshot(path=str(output / f'{prefix.replace("/", "-")}-{width}.png'), full_page=True)
        page.set_viewport_size({'width': 1280, 'height': 900})
        page.get_by_role('link', name='Finite sequences', exact=True).click()
        assert page.url.startswith(reference + 'VersoLeanRun/Sequence/')
        assert page.get_by_role('heading', name='Record and display a sequence', exact=True).count() == 1
        page.goto(reference + 'search/?q=Automaton.observe')
        result = page.locator('#search-page-results a').filter(has_text='Automaton.observe').first
        result.wait_for()
        result.click()
        assert page.url.startswith(reference + 'VersoLeanRun/Automaton/#')
        page.wait_for_function('document.getElementById(decodeURIComponent(location.hash.slice(1))) !== null')
        record(prefix + ': reference navigation, declaration search, and desktop/mobile layouts work')
        for module, fields in {
            'Frame': ['Frame.label', 'Frame.content', 'Frame.error'],
            'Sequence': ['Sequence.initial', 'Sequence.steps'],
            'Automaton': ['Automaton.initial', 'Automaton.step', 'AutomatonSession.initial', 'AutomatonSession.advance'],
        }.items():
            page.goto(reference + f'VersoLeanRun/{module}/')
            for theme in ['light', 'dark']:
                page.emulate_media(color_scheme=theme, reduced_motion='reduce')
                for width in [1280, 390]:
                    page.set_viewport_size({'width': width, 'height': 900})
                    for field in fields:
                        identity = 'VersoLeanRun___' + field.replace('.', '___')
                        layout = page.locator(f'[id="{identity}"]').evaluate('''field => {
                            const code = field.closest('code');
                            const doc = code.previousElementSibling;
                            const box = code.closest('.code-box');
                            if (!doc?.matches('.md-text, .verso-text') || !box) return false;
                            const bounds = box.getBoundingClientRect();
                            return doc.textContent.trim().length > 0 &&
                                [...doc.querySelectorAll('p')].every(p => {
                                    const r = p.getBoundingClientRect();
                                    return r.left >= bounds.left && r.right <= bounds.right;
                                }) && getComputedStyle(doc, '::before').content === 'none' &&
                                getComputedStyle(doc, '::after').content === 'none';
                        }''')
                        assert layout, (prefix, module, field, theme, width)
                    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (prefix, module, width)
                    if module == 'Frame':
                        page.locator('.code-content .code-box').first.screenshot(
                            path=str(output / f'{prefix.replace("/", "-")}-fields-{theme}-{width}.png'),
                            animations='disabled')
        record(prefix + ': field descriptions stay beside their declarations and wrap in light/dark desktop/phone layouts')
    static = browser.new_context(java_script_enabled=False).new_page()
    static.goto(base + 'root/api/')
    assert static.get_by_role('heading', name='Record a few steps or keep running?', exact=True).count() == 1
    assert 'def firstFive' in static.locator('main').inner_text()
    assert not errors, errors
    assert not failed_styles, failed_styles
    browser.close()
record('checked examples remain readable without JavaScript; styles load with correct MIME and code stays distinct in light/dark themes')
(output / 'results.json').write_text(json.dumps({'checks': checks}, indent=2) + '\n')
print(f'{len(checks)} API reference checks passed; evidence: {output}', flush=True)
