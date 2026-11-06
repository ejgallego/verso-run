"""Build the guide's copyable project through its published Git dependency."""
import argparse
import functools
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from playwright.sync_api import expect, sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/guide-project')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)


def guide_files():
    source = (ROOT / 'doc/VersoRunGuide/Authoring.lean').read_text()
    basic = source.split('tag := "guide-authoring-a-basic-block"', 1)[1].split('\n# ', 1)[0]
    chapter = re.findall(r'^````\n(.*?)^````$', basic, re.M | re.S)
    assert len(chapter) == 1
    files = {'MyChapter.lean': chapter[0]}
    for name in ['lean-toolchain', 'lakefile.lean', 'MyResources.lean', 'Main.lean']:
        blocks = re.findall(r'^`' + re.escape(name) + r'`:\n\n```\n(.*?)^```$', source, re.M | re.S)
        assert len(blocks) == 1, name
        files[name] = blocks[0]
    return files


report = {'acquisition': 'published-guide-project', 'checks': [], 'status': 'running'}
report_path = output / 'results.json'
report_path.write_text(json.dumps(report, indent=2) + '\n')


def record(name):
    report['checks'].append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


try:
    files = guide_files()
    dependency = re.search(r'require verso_run from git\s+"([^"]+)"\s+@\s+"([0-9a-f]{40})"', files['lakefile.lean'])
    assert dependency
    report.update(
        source=dependency[1], requestedRevision=dependency[2], toolchain=files['lean-toolchain'].strip(),
        sourceHashes={name: hashlib.sha256(text.encode()).hexdigest() for name, text in files.items()},
    )
    with tempfile.TemporaryDirectory(prefix='verso-run-guide-project-') as directory:
        project = Path(directory)
        command = functools.partial(run_command, output=output, cwd=project)
        try:
            for name, text in files.items():
                (project / name).write_text(text)
            assert not (project / '.lake').exists()
            command(['lake', 'update'], 'update')
            manifest = json.loads((project / 'lake-manifest.json').read_text())
            resolved = {p['name'].strip('«»'): p['rev'] for p in manifest['packages']}
            extension = project / '.lake/packages/verso_run'
            checkout = subprocess.check_output(['git', '-C', str(extension), 'rev-parse', 'HEAD'], text=True).strip()
            assert resolved['verso_run'] == checkout == report['requestedRevision']
            assert (extension / 'lean-toolchain').read_text().strip() == report['toolchain']
            expected = json.loads((extension / 'lake-manifest.json').read_text())
            for package in expected['packages']:
                assert resolved[package['name'].strip('«»')] == package['rev']
            for package in resolved:
                assert (project / '.lake/packages' / package / '.lake/build').resolve().is_relative_to(project)
            report['resolvedRevision'] = checkout
            record('verbatim guide files resolve their published dependency, toolchain and exact transitive pins')

            command(['lake', 'build'], 'build')
            command(['lake', 'exe', 'my-manual', '--output', '_out'], 'generate')
            site = project / '_out/html-multi'
            plan = json.loads((site / 'lean-run/publication.json').read_text())
            assert set(plan['programs']) == {'MyChapter'}
            assert set(plan['programs']['MyChapter']) == {'Demo.greet'}
            (output / 'publication.json').write_text(json.dumps(plan, indent=2) + '\n')
            record('ordinary Lake commands build the chapter, carrier and native publisher and publish the greeting')

            served = project / 'relocated'
            shutil.copytree(site, served)
            shutil.copytree(site, served / 'nested/project')
            with serve_directory(served) as base, sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
                page = browser.new_page()
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                for label, prefix in [('root', ''), ('nested', 'nested/project/')]:
                    assert page.goto(base + prefix).status == 200
                    form = page.locator('.lean-run[data-enhanced]')
                    expect(form.locator('input')).to_have_value('Ada')
                    form.locator('[type=submit]').click()
                    page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                                           arg=form.element_handle(), timeout=60000)
                    assert form.get_attribute('data-state') == 'success', form.inner_text()
                    assert form.locator('.lean-run-output').text_content() == 'Hello, Ada'
                    page.screenshot(path=str(output / (label + '.png')), full_page=True)
                    record(label + ': copied site runs the guide greeting in a real worker')
                assert not errors, errors
                browser.close()
        finally:
            # Retain the authored inputs, resolved manifest and logs, then let the
            # temporary project retire its own disposable dependency/build outputs.
            inputs = output / 'project-sources'
            inputs.mkdir(exist_ok=True)
            for name in [*files, 'lake-manifest.json']:
                if (project / name).is_file():
                    shutil.copy2(project / name, inputs / name)
    report['status'] = 'pass'
except Exception as error:
    report.update(status='fail', error=repr(error))
    raise
finally:
    report_path.write_text(json.dumps(report, indent=2) + '\n')

print(f'{len(report["checks"])} published guide-project checks passed; evidence: {output}', flush=True)
