"""Qualify native Blog Page/Post generation and their actual independent workers."""
from harness import run_command, inventory, serve_directory
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/blog-acceptance')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []
command = functools.partial(run_command, output=output, cwd=ROOT)

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


def oracle(role, value):
    return json.loads(subprocess.check_output([str(ROOT/'.lake/build/bin/lean-run-blog-oracle'), role, value], text=True))

site = output/'site'
command(['lake', 'exe', 'lean-run-blog-demo', '--output', str(site)], 'generate')
plan = json.loads((site/'lean-run/publication.json').read_text())
assert set(plan['programs']) == {'LeanRunBlog.Page', 'LeanRunBlog.Post'}
assert set(plan['programs']['LeanRunBlog.Post']) == {
    'LeanRunBlog.Examples.greet', 'LeanRunBlog.Examples.card', 'LeanRunBlog.Examples.count',
    'LeanRunBlog.Post.Inline.greet', 'LeanRunBlog.Post.Inline.card'}
record('typed Page/Post AST collection publishes independent canonical signatures')
(output/'lean-toolchain').write_text((ROOT/'lean-toolchain').read_text())
command([str(ROOT/'.lake/build/bin/lean-run-blog-demo'), '--output', str(output/'native-only')],
        'native-only', cwd=output)
assert plan == json.loads((output/'native-only/lean-run/publication.json').read_text())
assert inventory(site/'lean-run') == inventory(output/'native-only/lean-run')
record('Blog native generator runs outside the checkout with embedded assets')
accepted = (site/'lean-run/publication.json').read_bytes()
for mode, reason in [('missing', 'no published program bundle'), ('malformed', 'Invalid Blog Lean Run metadata')]:
    for destination in [site, output/('rejected-'+mode)]:
        error = command(['lake', 'exe', 'lean-run-blog-demo', '--check', mode, '--output', str(destination)],
                        mode+'-'+destination.name, expected=1)
        assert reason in error, error
    assert (site/'lean-run/publication.json').read_bytes() == accepted
    assert not (output/('rejected-'+mode)/'lean-run/publication.json').exists()
    record(mode+' metadata/registration fails before overwriting accepted publication')

# Root qualifies collection/planning; nested also exercises native draft generation.
for placement in ['root', 'nested']:
    hidden = output/('draft-hidden-'+placement)
    command(['lake', 'exe', 'lean-run-blog-draft-check', placement, 'hide', str(hidden)],
            'draft-hidden-'+placement)
    hidden_plan = json.loads((hidden/'lean-run/publication.json').read_text())
    assert hidden_plan['programs'] == {}
    post_path = Path('2026-10-8-running-lean-in-a-post/index.html')
    if placement == 'nested': post_path = Path('notes')/post_path
    assert not (hidden/post_path).exists()
    record(placement+': hidden draft needs no program bundle and emits no execution bindings')
    shown = output/('draft-shown-'+placement)
    command(['lake', 'exe', 'lean-run-blog-draft-check', placement, 'show', str(shown)],
            'draft-shown-'+placement)
    shown_plan = json.loads((shown/'lean-run/publication.json').read_text())
    assert set(shown_plan['programs']) == {'LeanRunBlog.Post'}
    assert shown_plan['programs']['LeanRunBlog.Post'] == plan['programs']['LeanRunBlog.Post']
    if placement == 'nested': assert (shown/post_path).is_file()
    record(placement+': explicit drafts publish canonical callable bindings')
    for destination in [shown, output/('draft-missing-'+placement)]:
        error = command(['lake', 'exe', 'lean-run-blog-draft-check', placement, 'missing', str(destination)],
                        'draft-missing-'+placement+'-'+destination.name, expected=1)
        assert 'no published program bundle' in error and 'LeanRunBlog.Post' in error
    assert json.loads((shown/'lean-run/publication.json').read_text()) == shown_plan
    assert not (output/('draft-missing-'+placement)).exists()
    record(placement+': visible draft without a bundle fails before overwriting or creating output')


served = output/'served'
for prefix in ['root', 'nested/prefix/blog']:
    shutil.copytree(site, served/prefix, dirs_exist_ok=True)
with serve_directory(served) as base:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width': 1280, 'height': 900})
        errors, workers = [], []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('worker', lambda worker: workers.append(worker))

        def form(name, index=0):
            return page.locator('.lean-run[data-experiment*="'+name+'"]').nth(index)

        def call(selected, value):
            selected.locator('input').fill(value)
            selected.locator('[type=submit]').click()
            page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                                   arg=selected.element_handle(), timeout=20000)
            assert selected.get_attribute('data-state') == 'success', selected.inner_text()
            return selected.locator('.lean-run-output').text_content()

        for prefix in ['root', 'nested/prefix/blog']:
            before = len(workers)
            page.goto(base+prefix+'/page/')
            page.wait_for_selector('.lean-run[data-enhanced]')
            assert len(workers) == before
            selected = form('LeanRunGate.Helper.twice')
            assert selected.get_attribute('data-lean-run-renderer') == '../lean-run/renderer.js'
            assert selected.locator('.lean-run-source .hl.lean').count() > 0
            assert selected.locator('[data-verso-hover]').count() > 0
            for value in ['0', '9007199254740993', '9'*128]:
                assert call(selected, value) == oracle('twice', value)
            record(prefix+': Page retains native highlighting, lazy loading, and exact Nat execution')
            before = len(workers)
            page.goto(base+prefix+'/notes/2026-10-8-running-lean-in-a-post/')
            page.wait_for_selector('.lean-run[data-enhanced]')
            assert len(workers) == before
            first, second = form('LeanRunBlog.Examples.greet'), form('LeanRunBlog.Examples.greet', 1)
            assert first.get_attribute('data-lean-run-renderer') == '../../lean-run/renderer.js'
            assert call(first, '世界 🌍 <b>&') == oracle('greet', '世界 🌍 <b>&')
            assert first.locator('.lean-run-output b').count() == 0
            assert call(second, 'independent') == oracle('greet', 'independent')
            assert first.locator('.lean-run-output').text_content() == oracle('greet', '世界 🌍 <b>&')
            assert len(set(page.locator('.lean-run').evaluate_all('(es) => es.map(e => e.dataset.instance)'))) == 7
            record(prefix+': Post Unicode and repeated placements have independent worker state')
            card = form('LeanRunBlog.Examples.card')
            assert call(card, '<b>& Ada') == ''
            frame = card.locator('iframe')
            assert oracle('card', '<b>& Ada') in frame.get_attribute('srcdoc')
            assert frame.get_attribute('sandbox') == ''
            assert card.frame_locator('iframe').locator('b').count() == 0
            card.locator('input').fill('Grace')
            assert frame.is_hidden()
            assert call(card, 'Grace') == ''
            record(prefix+': document-owned typed Html adapter escapes text and clears its preview')
            count = form('LeanRunBlog.Examples.count')
            assert call(count, '10') == oracle('count', '10')
            count.locator('input').fill('1000000000000')
            count.locator('[type=submit]').click()
            page.wait_for_function('e => e.dataset.state === "running"', arg=count.element_handle(), timeout=20000)
            count.locator('.lean-run-stop').click()
            assert count.get_attribute('data-state') == 'stopped'
            assert call(count, '11') == oracle('count', '11')
            record(prefix+': real synchronous worker Stop and fresh rerun')

        page.reload()
        page.wait_for_selector('.lean-run[data-enhanced]')
        first = form('LeanRunBlog.Examples.greet')
        page.route('**/program.irpkg', lambda route: route.fulfill(status=404, body='missing'))
        first.locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "failed"', arg=first.element_handle(), timeout=20000)
        assert '404' in first.locator('.lean-run-output').text_content()
        page.unroute('**/program.irpkg')
        assert call(first, 'retry') == oracle('greet', 'retry')
        record('Blog resource failure reports text and recovers only on explicit retry')
        page.screenshot(path=str(output/'post-desktop.png'), full_page=True)
        page.set_viewport_size({'width': 390, 'height': 844})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(output/'post-mobile.png'), full_page=True)
        record('Blog controls and collapsed source fit a narrow viewport')
        plain = browser.new_context(java_script_enabled=False)
        tab = plain.new_page()
        for path, name in [('page/', 'LeanRunGate.Helper.twice'),
                           ('notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Examples.greet')]:
            tab.goto(base+'root/'+path)
            selected = tab.locator('.lean-run[data-experiment*="'+name+'"]').first
            assert 'public def' in selected.locator('.lean-run-source').inner_text()
            assert selected.locator('[type=submit]').is_disabled()
        plain.close()
        record('Page and Post retain native source and disabled controls without JavaScript')
        assert not errors, errors
        record('no uncaught Blog browser errors')
        browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks, 'publication': plan}, indent=2)+'\n')
print(f'{len(checks)} Blog checks passed; evidence: {output}', flush=True)
