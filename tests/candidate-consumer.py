"""Consume an immutable candidate through Git in a separate, unseeded Lake project."""
import argparse
import functools
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from playwright.sync_api import expect, sync_playwright
from harness import inventory, run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--candidate', default='HEAD', help='commit to consume; must match this checkout')
parser.add_argument('--revision-kind', choices=['pr-head', 'synthetic-merge', 'commit'], default='commit')
parser.add_argument('--pr-head', help='original PR head when testing a synthetic merge')
parser.add_argument('--output', default='_out/candidate-consumer')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)


def git(*arguments, cwd=ROOT):
    return subprocess.check_output(['git', *arguments], cwd=cwd, text=True).strip()


revision = git('rev-parse', '--verify', args.candidate + '^{commit}')
assert revision == git('rev-parse', 'HEAD'), 'Candidate must match the checked-out test source'
parents = git('rev-list', '--parents', '-n', '1', revision).split()[1:]
pr_head = git('rev-parse', '--verify', args.pr_head + '^{commit}') if args.pr_head else None
if args.revision_kind == 'synthetic-merge':
    assert pr_head and len(parents) == 2 and parents[1] == pr_head, 'Synthetic merge must contain the selected PR head'
elif args.revision_kind == 'pr-head':
    assert pr_head is None or pr_head == revision
    pr_head = revision
expected_manifest = json.loads(git('show', revision + ':lake-manifest.json'))
project = Path(tempfile.mkdtemp(prefix='verso-run-candidate-')).resolve()
assert not project.is_relative_to(ROOT)
command = functools.partial(run_command, output=output, cwd=project)
checks = []
report = {
    'suite': 'candidate-downstream-integration', 'acquisition': 'local-git-bundle',
    'requestedRevision': revision, 'revisionKind': args.revision_kind, 'prHead': pr_head, 'parents': parents,
    'project': str(project), 'cold': True, 'lakeArtifactCache': False, 'checks': checks,
    'status': 'running',
}


def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


def save():
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')


try:
    bundle = output / 'candidate.bundle'
    command(['git', 'bundle', 'create', str(bundle), 'HEAD'], 'snapshot', cwd=ROOT)
    command(['git', 'bundle', 'verify', str(bundle)], 'snapshot-verify', cwd=ROOT)
    shutil.copytree(ROOT / 'tests/consumer', project, dirs_exist_ok=True)
    template = project / 'lakefile.lean.in'
    (project / 'lakefile.lean').write_text(template.read_text()
        .replace('{{source}}', json.dumps(str(bundle)))
        .replace('{{revision}}', json.dumps(revision)))
    template.unlink()
    (project / 'lean-toolchain').write_text(git('show', revision + ':lean-toolchain') + '\n')
    assert not any((project / name).exists() for name in ['.lake', '.vir-generated', '_out'])
    report['initialFiles'] = sorted(str(p.relative_to(project)) for p in project.rglob('*') if p.is_file())
    command(['lake', '--no-cache', 'build'], 'build')
    manifest = json.loads((project / 'lake-manifest.json').read_text())
    extension = next(p for p in manifest['packages'] if p['name'] == 'verso_run')
    extension_dir = project / '.lake/packages/verso_run'
    actual = git('rev-parse', 'HEAD', cwd=extension_dir)
    report.update(resolvedRevision=extension['rev'], extensionHead=actual, gitManifest=manifest)
    assert extension['type'] == 'git' and extension['url'] == str(bundle)
    assert revision == extension['rev'] == actual
    assert {(p['name'], p['url'], p['rev']) for p in manifest['packages'] if p['name'] != 'verso_run'} == {
        (p['name'], p['url'], p['rev']) for p in expected_manifest['packages']}
    for package in manifest['packages']:
        dependency = project / '.lake/packages' / package['name'].strip('«»')
        assert package['type'] == 'git' and not dependency.is_symlink()
        assert dependency.resolve().is_relative_to(project)
        assert git('rev-parse', 'HEAD', cwd=dependency) == package['rev']
        assert (dependency / '.lake/build').resolve().is_relative_to(project)
    record('exact candidate manifest/checkout and all dependency pins agree; fresh project owns every build directory')
    command([str(project / '.lake/build/bin/consumer-oracle')], 'native')
    native = json.loads((output / 'native.log').read_text())
    report['native'] = native
    assert native[-1]['scalar'] == '0'
    assert native[-1]['finite']['frames'][1]['html'] == '0'
    assert native[-1]['live'][1]['html'] == '0'
    assert all(case['independent'] == case['live'][1] for case in native)
    record('consumer-owned ordinary model produces finite, live and scalar native references including UInt64 wraparound')
    command(['lake', 'exe', 'consumer-manual', '--output', str(project / '_out'), '--with-html-single'], 'generate')
    site = project / '_out/html-multi'
    plan = json.loads((site / 'lean-run/publication.json').read_text())
    report['publication'] = plan
    bindings = plan['programs']['Consumer.Chapter']
    assert set(bindings) == {'Consumer.finite', 'Consumer.live', 'Consumer.increment'}
    assert bindings['Consumer.finite']['expectedExport']['effect'] == 'pure'
    assert bindings['Consumer.live']['expectedExport']['effect'] == 'runtime'
    assert bindings['Consumer.increment']['expectedExport']['effect'] == 'pure'
    assert set(plan['presenters']) == {'sequence', 'automaton'}
    vir = project / '.lake/packages/lean_vir'
    runtime_lock = json.loads((vir / 'vir-resources/runtime.json').read_text())
    report['runtimeContentId'] = runtime_lock['contentId']
    report['runtimePackSha256'] = hashlib.sha256((vir / '.vir-generated/VirResourceRuntime.virres').read_bytes()).hexdigest()
    assert runtime_lock['contentId'] in plan['runtimeManifest']
    assert (project / '.lake/build/lib/lean/vir-assets/Consumer/Chapter.virres').is_file()
    assert (extension_dir / '.lake/build/lib/lean/vir-assets/VersoLeanRunPresenter.virres').is_file()
    record('public Manual/publisher imports prepare consumer and dependency presenter resources through ordinary Lake needs')
    served = output / 'served'
    for prefix in ['root', 'nested/manual']:
        destination = served / prefix
        shutil.copytree(site, destination, dirs_exist_ok=True)
        assert inventory(destination) == inventory(site)
    # Remove the generated source site before HTTP execution: the server serves
    # only the copied files, and cannot fall back to the producer's output.
    hidden_site = project / '_out/generated-before-relocation'
    site.rename(hidden_site)
    with serve_directory(served) as base, sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        try:
            page = browser.new_page(viewport={'width': 1280, 'height': 1000})
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))

            def success(form):
                page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                                       arg=form.element_handle(), timeout=30000)
                assert form.get_attribute('data-state') == 'success', form.inner_text()

            def run(form, seed):
                form.locator('input[type=text]').fill(seed)
                form.locator('[type=submit]').click()
                success(form)

            def live_frame(form, expected):
                frame = form.locator('iframe[data-preview="current"]')
                assert expected['html'] in frame.get_attribute('srcdoc')
                assert frame.get_attribute('sandbox') == ''
                expect(form.locator('.lean-run-sequence-position')).to_have_text(expected['label'])
                assert form.locator('.lean-run-sequence-error').text_content() == (expected['error'] or '')
                expect(form.frame_locator('iframe[data-preview="current"]').locator('body')).to_have_text(expected['html'])

            def advance(form, expected):
                form.locator('.lean-run-step').click()
                success(form)
                live_frame(form, expected)

            for prefix in ['root', 'nested/manual']:
                scalar = page.locator('.lean-run[data-experiment*="Consumer.increment"]')
                finite = page.locator('.lean-run[data-experiment*="Consumer.finite"]')
                live = page.locator('.lean-run[data-experiment*="Consumer.live"]')
                for case in native:
                    page.goto(base + prefix + '/Scalar/')
                    page.wait_for_selector('.lean-run[data-enhanced]')
                    run(scalar, case['seed'])
                    assert scalar.locator('.lean-run-output').text_content() == case['scalar']
                    page.goto(base + prefix + '/Finite/')
                    page.wait_for_selector('.lean-run[data-enhanced]')
                    assert json.loads(finite.get_attribute('data-experiment'))['callable'] == 'Consumer.Chapter.Consumer.finite.leanRun'
                    run(finite, case['seed'])
                    for index, expected in enumerate(case['finite']['frames']):
                        finite.locator(f'[data-step="{index}"]').click()
                        assert finite.locator('.lean-run-sequence-position').text_content() == (
                            f"Step {index + 1} of {len(case['finite']['frames'])}: {expected['label']}")
                        expect(finite.frame_locator('iframe').locator('body')).to_have_text(expected['html'])
                        assert finite.locator('.lean-run-sequence-error').text_content() == (expected['error'] or '')
                    page.goto(base + prefix + '/Live/')
                    page.wait_for_selector('.lean-run[data-enhanced]')
                    assert live.count() == 2
                    assert json.loads(live.nth(0).get_attribute('data-experiment'))['callable'] == 'Consumer.Chapter.Consumer.live.leanRun'
                    run(live.nth(0), case['seed'])
                    live_frame(live.nth(0), case['live'][0])
                    for expected in case['live'][1:]:
                        advance(live.nth(0), expected)
                record(prefix + ': scalar calls, every finite frame and live advancements agree with the native consumer')
                page.goto(base + prefix + '/Live/')
                page.wait_for_selector('.lean-run[data-enhanced]')
                first, second = live.nth(0), live.nth(1)
                a, b = native[-1], native[1]
                run(first, a['seed'])
                run(second, b['seed'])
                advance(first, a['live'][1])
                live_frame(second, b['live'][0])
                advance(first, a['live'][2])
                advance(second, b['independent'])
                live_frame(first, a['live'][2])
                first.locator('.lean-run-stop').click()
                assert first.get_attribute('data-state') == 'stopped'
                advance(second, b['live'][2])
                record(prefix + ': repeated live placements advance independently; stopping one preserves the other')
            assert not errors, errors
        finally:
            browser.close()
    report['status'] = 'pass'
except Exception as error:
    report.update(status='fail', error=repr(error))
    raise
finally:
    save()
print(f'{len(checks)} candidate downstream checks passed for {revision} ({args.revision_kind}); evidence: {output}', flush=True)
