"""Known Life rules and real worker/native generation views in all genres."""
import argparse, functools, http.server, json, shutil, subprocess, threading
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/life-acceptance')
parser.add_argument('--site', help='reuse the sequence campaign native output')
args = parser.parse_args()
output = Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
checks = []

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)

def command(argv, name):
    result = subprocess.run(argv, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output/(name+'.log')).write_text(result.stdout)
    assert result.returncode == 0, result.stdout[-4000:]

def oracle(seed):
    return json.loads(json.loads(subprocess.check_output(
        [str(ROOT/'.lake/build/bin/lean-run-oracle'), 'life', seed], text=True)))

command(['lake','env','lean','tests/Life.lean'], 'rules')
record('Lean rules: block, blinker, extinction, translated glider, dead boundaries, parsing and output budget')
site = Path(args.site).resolve() if args.site else output/'site'
if not args.site:
    command(['lake','exe','lean-run-demo','--output',str(site/'manual'),'--with-tex'],'manual')
    command(['lake','exe','lean-run-blog-demo','--output',str(site/'blog')],'blog')
    command(['lake','exe','lean-run-slides-demo','--output',str(site/'slides')],'slides')
served = output/'served'
for prefix in ['root','nested/prefix']:
    for genre, source in [('manual',site/'manual/html-multi'),('blog',site/'blog'),('slides',site/'slides')]:
        shutil.copytree(source,served/prefix/genre,dirs_exist_ok=True)

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*_): pass
    def handle(self):
        try: super().handle()
        except (BrokenPipeError,ConnectionResetError): pass

server = http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=str(served)))
threading.Thread(target=server.serve_forever,daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}/'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width':1280,'height':1000})
        errors = []; page.on('pageerror',lambda error: errors.append(str(error)))
        def form(): return page.locator('.lean-run[data-experiment*="LeanRunSequence.Life.lifeView"]')
        def visit(prefix,genre,path):
            page.goto(base+prefix+'/'+genre+'/'+path)
            page.wait_for_selector('.lean-run[data-enhanced]')
            if genre=='slides':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                page.evaluate('Reveal.slide(11,0)')
                page.wait_for_function('Reveal.getIndices().h === 11')
        def run(seed):
            form().locator('textarea').fill(seed)
            form().locator('[type=submit]').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)',arg=form().element_handle(),timeout=30000)
            assert form().get_attribute('data-state')=='success',form().inner_text()
            expected = oracle(seed)
            for index, frame in enumerate(expected['frames']):
                form().locator(f'[data-step="{index}"]').click()
                assert frame['html'] in form().locator('iframe').get_attribute('srcdoc')
                assert form().locator('iframe').get_attribute('sandbox')==''
                assert form().locator('.lean-run-sequence-error').text_content()==(frame['error'] or '')
                assert form().frame_locator('iframe').locator('svg').get_attribute('aria-label').startswith('Game of Life generation')
            return expected
        for prefix in ['root','nested/prefix']:
            for genre,path in [('manual','Game-of-Life/'),('blog','page/'),
                               ('blog','notes/2026-10-8-running-lean-in-a-post/'),('slides','')]:
                visit(prefix,genre,path)
                expected=run('.#.\n..#\n###')
                assert len(expected['frames'])==13 and all(f['error'] is None for f in expected['frames'])
                assert 'Generation 12 · 5 living cells' in expected['frames'][-1]['html']
                record(prefix+'/'+genre+'/'+path+': editable glider and every Lean generation agree with native execution')
        visit('root','manual','Game-of-Life/')
        for seed in ['.##.\n.##.','...\n###\n...','#', '\n'.join(['########']*8)]:
            expected=run(seed)
            assert len(expected['frames'])==13 and all(f['error'] is None for f in expected['frames'])
        record('still life, blinker, extinction and dense boards execute and render within the worker budget')
        for seed in ['', '#\n..', '#########', '\n'.join(['.']*9), '<script>']:
            expected=run(seed)
            assert len(expected['frames'])==1 and expected['frames'][0]['error']
        expected=run('.#.\n..#\n###')
        record('invalid shape/character/size is a Lean sequence error; a valid seed recovers')
        form().locator('textarea').fill('#')
        assert form().locator('.lean-run-sequence').is_hidden()
        expected=run('...\n###\n...')
        slider=form().locator('input[type=range]')
        slider.evaluate('(e) => {e.value="1";e.dispatchEvent(new Event("input",{bubbles:true}));}')
        assert expected['frames'][1]['html'] in form().locator('iframe').get_attribute('srcdoc')
        record('editing invalidates the old board; the shared scrubber selects the new Lean state')
        for width in [1280,390]:
            page.set_viewport_size({'width':width,'height':1000})
            run('.#.\n..#\n###')
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
            assert form().frame_locator('iframe').locator('svg').bounding_box()['width']<=176
            page.screenshot(path=str(output/f'life-{width}.png'),full_page=True)
        record('desktop/mobile seed and controls fit, with the full SVG board visible')
        context=browser.new_context(java_script_enabled=False);plain=context.new_page()
        for genre,path in [('manual','Game-of-Life/'),('blog','page/'),('slides','')]:
            plain.goto(base+'root/'+genre+'/'+path)
            static=plain.locator('.lean-run[data-experiment*="LeanRunSequence.Life.lifeView"]')
            assert 'lifeView' in static.locator('.lean-run-source').text_content()
            assert static.locator('[type=submit]').is_disabled()
        assert 'lifeView' in (site/'manual/tex/main.tex').read_text()
        context.close()
        assert not errors,errors
        record('all genres retain static source, Manual TeX, and no uncaught browser errors')
        browser.close()
finally:
    server.shutdown();server.server_close()
(output/'results.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
print(f'{len(checks)} Life checks passed; evidence: {output}',flush=True)
