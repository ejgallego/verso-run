"""Compile exact Cast source against this checkout's unchanged dependency pins.

The experimental consumer owns all dependencies and outputs. No Cast build files,
runtime or SDK are copied. This is a source-compatibility gate, not editor/runtime
acceptance. Run --prepare first when using an interactive Lean checker, close that
workspace, then run --build for batch evidence. --shell compiles a registered
wrapper using the existing infoview hash-import route; a separate browser driver
checks the official loader with controlled source replies.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cast-source', type=Path, required=True, help='Git checkout containing the source commit')
parser.add_argument('--cast-revision', default='0e2bc830bc43a88fc3ceea55616911924a0a83d6')
parser.add_argument('--output', type=Path, default=ROOT / '_out/cast-compatibility')
parser.add_argument('--prepare', action='store_true', help='acquire the isolated consumer without compiling')
parser.add_argument('--build', action='store_true', help='build an already prepared consumer')
parser.add_argument('--shell', action='store_true', help='compile and extract a registered shell wrapper')
parser.add_argument('--preview', action='store_true', help='compile public Preview client/server consumer APIs')
args = parser.parse_args()
assert sum([args.prepare, args.build, args.shell, args.preview]) == 1, 'Select --prepare, --build, --shell or --preview'
output = args.output.resolve()
assert output.is_relative_to(ROOT / '_out'), 'Keep experimental outputs inside this task worktree'
project = output / 'consumer'
report_path = output / 'results.json'
output.mkdir(parents=True, exist_ok=True)


def git(*parts, cwd=args.cast_source):
    return subprocess.check_output(['git', *parts], cwd=cwd, text=True).strip()


def write_report(report):
    report_path.write_text(json.dumps(report, indent=2) + '\n')


def run(parts, log_name, cwd=project):
    print('RUN', ' '.join(map(str, parts)), flush=True)
    with (output / log_name).open('w') as log:
        subprocess.run(parts, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, check=True)


def check_dependencies(expected):
    actual = json.loads((project / 'lake-manifest.json').read_text())
    selected = {(p['name'], p['url'], p['rev']) for p in expected['packages']}
    assert {(p['name'], p['url'], p['rev']) for p in actual['packages']} == selected
    for package in actual['packages']:
        dependency = project / '.lake/packages' / package['name'].strip('«»')
        assert not dependency.is_symlink() and dependency.resolve().is_relative_to(project)
        assert git('rev-parse', 'HEAD', cwd=dependency) == package['rev']
        assert (dependency / '.lake/build').resolve().is_relative_to(project)
    return actual


if args.prepare:
    assert not project.exists(), 'Refuse to overwrite an existing compatibility consumer'
    revision = git('rev-parse', '--verify', args.cast_revision + '^{commit}')
    expected = json.loads((ROOT / 'lake-manifest.json').read_text())
    report = {'suite': 'cast-source-compatibility', 'castRevision': revision,
              'consumerBase': git('rev-parse', 'HEAD', cwd=ROOT),
              'project': str(project), 'status': 'preparing', 'runtimeQualified': False,
              'editorQualified': False, 'expectedManifest': expected}
    write_report(report)
    project.mkdir()
    source = project / 'cast-source'
    source.mkdir()
    archive = subprocess.check_output(['git', 'archive', '--format=tar', revision,
                                      'VersoCast.lean', 'VersoCast'], cwd=args.cast_source)
    inventory = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as members:
        for member in members:
            if member.isdir():
                continue
            assert member.isfile() and member.name.endswith('.lean'), member.name
            target = source / member.name
            assert target.resolve().is_relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            contents = members.extractfile(member).read()
            target.write_bytes(contents)
            inventory[member.name] = hashlib.sha256(contents).hexdigest()
    report['sourceFiles'] = inventory
    prefix = (ROOT / 'lakefile.lean').read_text().split('\npackage verso_run', 1)[0]
    (project / 'lakefile.lean').write_text(prefix + '''

package cast_source_compat where
  leanOptions := #[⟨`experimental.module, true⟩]

lean_lib CastSource where
  srcDir := "cast-source"
  roots := #[`VersoCast]
  requiresModuleSystem := true

lean_lib Compatibility where
  requiresModuleSystem := true
''')
    shutil.copyfile(ROOT / 'lean-toolchain', project / 'lean-toolchain')
    shutil.copyfile(ROOT / 'experiments/cast-compatibility/Compatibility.lean', project / 'Compatibility.lean')
    manifest = {**expected, 'name': 'cast_source_compat'}
    (project / 'lake-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    try:
        run(['lake', 'update'], 'acquire.log')
        report['resolvedManifest'] = check_dependencies(expected)
        report['status'] = 'prepared'
    except Exception as error:
        report.update(status='preparation-failed', error=str(error))
        raise
    finally:
        write_report(report)
    print(f'Prepared isolated consumer: {project}', flush=True)
elif args.build:
    report = json.loads(report_path.read_text())
    assert report['status'] in ['prepared', 'build-failed', 'source-compile-passed']
    check_dependencies(report['expectedManifest'])
    for name, digest in report['sourceFiles'].items():
        assert hashlib.sha256((project / 'cast-source' / name).read_bytes()).hexdigest() == digest
    fixture = (ROOT / 'experiments/cast-compatibility/Compatibility.lean').read_bytes()
    assert (project / 'Compatibility.lean').read_bytes() == fixture, 'Prepared fixture differs from source'
    report['fixtureSha256'] = hashlib.sha256(fixture).hexdigest()
    try:
        run(['lake', '--no-cache', 'build', '+Compatibility:olean'], 'build.log')
        report['resolvedManifest'] = check_dependencies(report['expectedManifest'])
        report['status'] = 'source-compile-passed'
    except Exception as error:
        report.update(status='build-failed', error=str(error))
        raise
    finally:
        write_report(report)
    print('PASS exact Cast core/Manual source compile; runtime/editor remain unqualified', flush=True)
elif args.shell:
    report = json.loads(report_path.read_text())
    assert report['status'] == 'source-compile-passed'
    check_dependencies(report['expectedManifest'])
    fixture = ROOT / 'experiments/cast-compatibility/WidgetComposition.lean'
    shutil.copyfile(fixture, project / fixture.name)
    lakefile = project / 'lakefile.lean'
    addition = '\nlean_lib WidgetComposition where\n  requiresModuleSystem := true\n'
    if addition not in lakefile.read_text():
        lakefile.write_text(lakefile.read_text() + addition)
    vir = project / '.lake/packages/lean_vir'
    lock = (vir / 'package-lock.json').read_bytes()
    try:
        run(['npm', 'ci', '--cache', str(project / '.cache/npm')], 'npm.log', cwd=vir)
        assert (vir / 'package-lock.json').read_bytes() == lock
        run(['lake', '--no-cache', 'build', '+WidgetComposition:olean'], 'shell-build.log')
        artifact = json.loads((project / 'widget-composition.json').read_text())
        expected_import = "import VirShell from 'widget_module:hash," + artifact['shellHash'] + "';"
        assert artifact['wrapperSource'].startswith(expected_import)
        report['shell'] = {'status': 'registered-wrapper-compiled',
                           'shellHash': artifact['shellHash'], 'wrapperHash': artifact['wrapperHash'],
                           'fixtureSha256': hashlib.sha256(fixture.read_bytes()).hexdigest(),
                           'loaderQualified': False}
    except Exception as error:
        report['shell'] = {'status': 'compile-failed', 'error': str(error)}
        raise
    finally:
        write_report(report)
    print('PASS registered wrapper compiles; loader/runtime/editor remain unqualified', flush=True)
else:
    report = json.loads(report_path.read_text())
    assert report['status'] in ['prepared', 'build-failed', 'source-compile-passed']
    check_dependencies(report['expectedManifest'])
    for name, digest in report['sourceFiles'].items():
        assert hashlib.sha256((project / 'cast-source' / name).read_bytes()).hexdigest() == digest
    assert (project / 'cast-source/VersoCast/Manual/Preview.lean').is_file()
    fixture = ROOT / 'experiments/cast-compatibility/PreviewCompatibility.lean'
    shutil.copyfile(fixture, project / fixture.name)
    shutil.copyfile(ROOT / 'experiments/cast-compatibility/Compatibility.lean', project / 'Compatibility.lean')
    lakefile = project / 'lakefile.lean'
    addition = '\nlean_lib PreviewCompatibility where\n  requiresModuleSystem := true\n'
    if addition not in lakefile.read_text():
        lakefile.write_text(lakefile.read_text() + addition)
    vir = project / '.lake/packages/lean_vir'
    lock = (vir / 'package-lock.json').read_bytes()
    try:
        run(['npm', 'ci', '--cache', str(project / '.cache/npm')], 'preview-npm.log', cwd=vir)
        assert (vir / 'package-lock.json').read_bytes() == lock
        run(['lake', '--no-cache', 'build', '+PreviewCompatibility:olean'], 'preview-build.log')
        report['resolvedManifest'] = check_dependencies(report['expectedManifest'])
        report['status'] = 'source-compile-passed'
        report['preview'] = {'status': 'public-imports-compiled',
                             'fixtureSha256': hashlib.sha256(fixture.read_bytes()).hexdigest(),
                             'lifecycleQualified': False}
    except Exception as error:
        report['preview'] = {'status': 'compile-failed', 'error': str(error)}
        raise
    finally:
        write_report(report)
    print('PASS public Preview client/server API compile; lifecycle/editor/runtime remain unqualified', flush=True)
