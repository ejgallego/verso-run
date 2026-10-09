"""Inline Page/Post/Slides authoring, native source, independent workers and Html."""
from harness import run_command, serve_directory
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/inline-genres')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []
command = functools.partial(run_command, output=output, cwd=ROOT)

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


fixtures = output/'author'
fixtures.mkdir(exist_ok=True)
for genre, module, opening, document in [
    ('Page', 'Blog', 'Verso Genre Blog VersoLeanRun.Blog', '(Page) "Inline test"'),
    ('Post', 'Blog', 'Verso Genre Blog VersoLeanRun.Blog', '(Post) "Inline test"'),
    ('Slides', 'Slides', 'Verso VersoSlides VersoLeanRun.Slides', '(VersoSlides.Slides) "Inline test"')]:
    header = f'module\npublic import VersoLeanRun.{module}\nopen {opening}\nset_option compiler.postponeCompile false\n#doc {document} =>\n'
    if genre == 'Post': header += '\n%%%\nauthors := ["test"]\ndate := {year := 2026, month := 10, day := 8}\n%%%\n'
    body = '''
```leanRun (entry := InlineTest.text) +multiline
namespace InlineTest
public def text (input : String) : String := input
```
```leanRun (entry := natural)
public def natural (input : Nat) : Nat := input + 1
```
```leanRun (entry := boolean) (input := "false")
public def boolean (input : Bool) : Bool := !input
```
```leanRun (entry := word) (input := "18446744073709551615")
public def word (input : UInt64) : UInt64 := input + 1
```
```leanRun (entry := text) +collapsed
#check text
```
```leanRun (entry := InlineTest.html)
public def html (input : String) : Verso.Output.Html := .text true input
end InlineTest
```
'''
    file = fixtures/(genre+'.lean')
    file.write_text(header+body)
    command(['lake', 'env', 'lean', str(file)], genre+'-author')
    record(genre+': annotation-free scalar/Html definitions, retained namespace and repeated selection')
    for role, block, reason in [
        ('unsupported', '```leanRun (entry := signed)\npublic def signed (n : Int) : Int := n\n```', 'supported by VIR, but not by this Run form'),
        ('output', '```leanRun (entry := text) (output := "html")\npublic def text (s : String) : String := s\n```', 'Unexpected argument (output :=')]:
        file = fixtures/(genre+'-'+role+'.lean')
        file.write_text(header+'\n'+block+'\n')
        error = command(['lake', 'env', 'lean', str(file)], genre+'-'+role, expected=1)
        assert reason in error, error
        assert str(file) in error
        record(genre+': '+role+' rejected with author source location')

site = output/'site'
command(['lake', 'exe', 'lean-run-blog-demo', '--output', str(site/'blog')], 'blog')
command(['lake', 'exe', 'lean-run-slides-demo', '--output', str(site/'slides')], 'slides')
plans = {genre: json.loads((site/genre/'lean-run/publication.json').read_text()) for genre in ['blog', 'slides']}
descriptor = {'type': 'String', 'interfaceTag': 3}
for genre, owner in [('blog', 'LeanRunBlog.Page'), ('blog', 'LeanRunBlog.Post'), ('slides', 'LeanRunSlides.Deck')]:
    for role in ['greet', 'card']:
        assert plans[genre]['programs'][owner][owner+'.Inline.'+role]['expectedExport'] == {
            'args': [descriptor], 'result': descriptor, 'effect': 'pure'}
record('independent canonical String signatures for inline scalar and Html callables')


served = output/'served'
for prefix in ['root', 'nested/prefix']:
    for genre in ['blog', 'slides']:
        shutil.copytree(site/genre, served/prefix/genre, dirs_exist_ok=True)
with serve_directory(served) as base:

    def oracle(role, value):
        return json.loads(subprocess.check_output([str(ROOT/'.lake/build/bin/lean-run-blog-oracle'), role, value], text=True))

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width': 1280, 'height': 900})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))

        def form(owner, role, index=0):
            return page.locator('.lean-run[data-experiment*="'+owner+'.Inline.'+role+'"]').nth(index)

        def success(selected, value):
            selected.locator('input').fill(value)
            selected.locator('[type=submit]').click()
            page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)', arg=selected.element_handle(), timeout=30000)
            assert selected.get_attribute('data-state') == 'success', selected.inner_text()
            return selected.locator('.lean-run-output').text_content()

        def slide(index, fragment=False):
            page.evaluate('(n) => Reveal.slide(n, 0)', index)
            page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)
            if fragment: page.evaluate('Reveal.nextFragment()')

        for prefix in ['root', 'nested/prefix']:
            for genre, path, owner, role in [
                ('blog', 'page/', 'LeanRunBlog.Page', 'page'),
                ('blog', 'notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Post', 'post'),
                ('slides', '', 'LeanRunSlides.Deck', 'slide')]:
                page.goto(base+prefix+'/'+genre+'/'+path)
                page.wait_for_selector('.lean-run[data-enhanced]')
                if genre == 'slides':
                    page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                    slide(7, fragment=True)
                first, second = form(owner, 'greet'), form(owner, 'greet', 1)
                data = json.loads(first.get_attribute('data-experiment'))
                assert data['program'] == owner
                assert data['callable'] == data['declaration'] == owner+'.Inline.greet'
                assert data['form'] == 'string'
                assert '@[vir_export]' not in first.locator('.lean-run-source').text_content()
                assert first.locator('.lean-run-source .hl.lean').count() > 0
                value = '世界 🌍 <b>&'
                assert success(first, value) == oracle(role+'InlineGreet', value)
                assert first.locator('.lean-run-output b').count() == 0
                if genre == 'slides':
                    page.evaluate('Reveal.prevFragment()')
                    page.wait_for_function('e => e.dataset.state === "stopped"', arg=first.element_handle())
                    assert first.locator('.lean-run-output').text_content() == ''
                    assert first.locator('[type=submit]').is_disabled()
                    for _ in range(50):
                        if not page.workers: break
                        page.wait_for_timeout(100)
                    assert not page.workers
                    slide(8)
                assert success(second, 'independent') == oracle(role+'InlineGreet', 'independent')
                assert first.get_attribute('data-instance') != second.get_attribute('data-instance')
                if genre != 'slides':
                    assert first.locator('.lean-run-output').text_content() == oracle(role+'InlineGreet', value)
                record(prefix+'/'+role+': native inline execution, namespace reuse and independent placements')
                if genre == 'slides': slide(9)
                card = form(owner, 'card')
                data = json.loads(card.get_attribute('data-experiment'))
                assert data['declaration'] == owner+'.Inline.card'
                assert data['callable'] == owner+'.Inline.card.leanRunHtml'
                assert data['form'] == 'html'
                assert success(card, '<b>& 🌍') == ''
                iframe = card.locator('iframe')
                assert oracle(role+'InlineCard', '<b>& 🌍') in iframe.get_attribute('srcdoc')
                assert iframe.get_attribute('sandbox') == ''
                assert card.frame_locator('iframe').locator('b').count() == 0
                record(prefix+'/'+role+': inline typed Html serializes and escapes in its sandbox')

        plain = browser.new_context(java_script_enabled=False, viewport={'width': 390, 'height': 900})
        tab = plain.new_page()
        for genre, path, owner in [('blog', 'page/', 'LeanRunBlog.Page'),
                                   ('blog', 'notes/2026-10-8-running-lean-in-a-post/', 'LeanRunBlog.Post'),
                                   ('slides', '', 'LeanRunSlides.Deck')]:
            tab.goto(base+'root/'+genre+'/'+path)
            selected = tab.locator('.lean-run[data-experiment*="'+owner+'.Inline.greet"]').first
            assert 'public def greet' in selected.locator('.lean-run-source').text_content()
            assert selected.locator('[type=submit]').is_disabled()
            assert tab.evaluate('document.documentElement.scrollWidth <= innerWidth')
            record(owner+': native inline source and disabled controls remain readable without JavaScript')
        plain.close()
        assert not errors, errors
        record('no uncaught inline genre browser errors')
        browser.close()

(output/'results.json').write_text(json.dumps({'checks': checks, 'publications': plans}, indent=2)+'\n')
print(f'{len(checks)} inline genre checks passed; evidence: {output}', flush=True)
