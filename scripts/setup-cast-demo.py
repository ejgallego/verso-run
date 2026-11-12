"""Prepare the optional infoview demo from this worktree's selected dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime-kit', type=Path,
                    help='self-contained matched VIR source/SDK/runtime kit; installs a local override')
parser.add_argument('--cast-source-kit', type=Path, help='frozen Cast source-only qualification handoff')
parser.add_argument('--editor-fixture', action='store_true', help='prepare the clean editor acceptance fixture')
args = parser.parse_args()
environment = os.environ.copy()
logs = ROOT / '_out/cast-demo'
logs.mkdir(parents=True, exist_ok=True)


def run(command, name, cwd=ROOT):
    print('RUN', ' '.join(map(str, command)), flush=True)
    with (logs / (name + '.log')).open('w') as stream:
        subprocess.run(command, cwd=cwd, env=environment, stdout=stream,
                       stderr=subprocess.STDOUT, check=True)


def git(*arguments, cwd):
    return subprocess.check_output(['git', *arguments], cwd=cwd, text=True).strip()


if args.cast_source_kit:
    handoff = args.cast_source_kit.resolve(strict=True)
    record = json.loads((handoff / 'SOURCE.json').read_text())
    selected = next(row for row in json.loads((ROOT / 'lake-manifest.json').read_text())['packages']
                    if row['name'] == '«verso-cast»')
    archive = handoff / 'source.tar'
    if (selected['rev'] != record['base'] or
            hashlib.sha256(archive.read_bytes()).hexdigest() != record['archiveSha256'] or
            hashlib.sha256((handoff / 'source.patch').read_bytes()).hexdigest() != record['identity']):
        raise SystemExit('The frozen Cast source handoff does not match its recorded base/hash')
    if not args.runtime_kit:
        raise SystemExit('The Lean preview source requires its matched --runtime-kit')
    runtime = json.loads((args.runtime_kit / 'ARTIFACTS.json').read_text())
    runtime_checkpoint = json.loads((args.runtime_kit / 'CHECKPOINT.json').read_text())
    verso = next(row for row in json.loads((ROOT / 'lake-manifest.json').read_text())['packages']
                 if row['name'] == 'verso')
    if (record['apiSource'] != runtime['source'] or record['sdkSha256'] != runtime['SDK']['sha256'] or
            record['runtimeLockSource'] != runtime_checkpoint['lockSourceCommit'] or
            record['runtimeContentId'] != runtime['runtime']['contentId'] or
            verso['rev'] != record['verso'] or (ROOT / 'lean-toolchain').read_text().strip() != record['toolchain']):
        raise SystemExit('Cast preview requires the exact reviewed source/SDK/runtime/toolchain')
    target = logs / ('cast-source-' + record['identity'][:12])
    source = target / 'source'
    # Compare a retained source copy before reuse; never overwrite source edits.
    with tarfile.open(archive) as stream:
        if source.exists():
            for member in stream.getmembers():
                if member.isfile():
                    path = source / member.name
                    if not path.is_file() or path.read_bytes() != stream.extractfile(member).read():
                        raise SystemExit('Preserving edits in the frozen Cast source copy')
        else:
            source.mkdir(parents=True)
            stream.extractall(source, filter='data')
    for row in record['files']:
        if hashlib.sha256((source / row['path']).read_bytes()).hexdigest() != row['sha256']:
            raise SystemExit('Frozen Cast source file checksum mismatch')
    override_file = ROOT / '.lake/package-overrides.json'
    config = json.loads(override_file.read_text()) if override_file.exists() else {'version': '1.3.0', 'packages': []}
    entry = {'name': '«verso-cast»', 'type': 'path', 'dir': str(source), 'inherited': False,
             'configFile': 'lakefile.lean', 'manifestFile': 'lake-manifest.json'}
    existing = [row for row in config['packages'] if row['name'] == '«verso-cast»']
    if existing not in ([], [entry]):
        if len(existing) != 1 or existing[0]['type'] != 'path' or not (ROOT / existing[0]['dir']).resolve().is_relative_to(logs):
            raise SystemExit('Preserving a different existing Cast package override')
        # Switching an owned source selection leaves its previous directory and
        # edits intact. Retain the selector too for review.
        (logs / 'previous-cast-selection.json').write_text(json.dumps(existing, indent=2) + '\n')
    config['packages'] = [row for row in config['packages'] if row['name'] != '«verso-cast»'] + [entry]
    override_file.write_text(json.dumps(config, indent=2) + '\n')

public_vir = ROOT / '.lake/packages/lean_vir'
override_file = ROOT / '.lake/package-overrides.json'
config = json.loads(override_file.read_text()) if override_file.exists() else {'version': '1.3.0', 'packages': []}
selected = [row for row in config['packages'] if row['name'] == 'lean_vir']
if len(selected) > 1:
    raise SystemExit('Expected one VIR workspace selection')
vir = (ROOT / selected[0]['dir']).resolve() if selected and selected[0]['type'] == 'path' else public_vir
if selected and not args.runtime_kit:
    raise SystemExit('Pass --runtime-kit to reproduce the selected local VIR source and SDK together')

if args.runtime_kit:
    kit = args.runtime_kit.resolve(strict=True)
    checkpoint = json.loads((kit / 'CHECKPOINT.json').read_text())
    receipt = json.loads((kit / 'ARTIFACTS.json').read_text())
    reference = receipt['publicReferenceBase']
    api = receipt['source']
    public = next(row for row in json.loads((ROOT / 'lake-manifest.json').read_text())['packages']
                  if row['name'] == 'lean_vir')
    if public['rev'] != reference or git('rev-parse', 'HEAD', cwd=public_vir) != reference:
        raise SystemExit('The integration kit does not match the public reference pin')
    if (checkpoint['API_SDK_Source'] != api or checkpoint['publicReferenceBase'] != reference or
            receipt['SDK']['sourceGitCommit'] != api or
            checkpoint['onlyChangedPath'] != 'vir-resources/runtime.json' or
            not checkpoint['bundleSelfContained'] or checkpoint['bundlePrerequisites']):
        raise SystemExit('Expected one self-contained, source-paired local integration kit')
    for line in (kit / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        path = kit / name.removeprefix('*')
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f'Integration kit checksum mismatch: {name}')
    sdk = kit / receipt['SDK']['archive']
    pack = kit / receipt['runtime']['pack']
    for path, record in [(sdk, receipt['SDK']), (pack, receipt['runtime'])]:
        data = path.read_bytes()
        if len(data) != record['byteLength'] or hashlib.sha256(data).hexdigest() != record['sha256']:
            raise SystemExit(f'Matched artifact checksum mismatch: {path.name}')
    bundle = kit / checkpoint['bundle']
    if hashlib.sha256(bundle.read_bytes()).hexdigest() != checkpoint['bundleSha256']:
        raise SystemExit('Integration source bundle checksum mismatch')
    lock = json.loads((kit / 'runtime.local.json').read_text())
    if lock != receipt['localSelection']:
        raise SystemExit('Local runtime selection differs from the matched receipt')
    local = logs / ('lean-vir-' + checkpoint['lockSourceCommit'][:12])
    entry = {'name': 'lean_vir', 'type': 'path', 'dir': str(local), 'inherited': False,
             'configFile': 'lakefile.lean', 'manifestFile': 'lake-manifest.json'}
    if selected and selected != [entry]:
        previous = (ROOT / selected[0].get('dir', '')).resolve()
        # Replace only this worktree's clean, prepared lock-only selection.
        if (selected[0]['type'] != 'path' or not previous.is_relative_to(logs) or
                git('status', '--porcelain', cwd=previous) or
                git('diff', '--name-only', 'HEAD^', 'HEAD', cwd=previous) != 'vir-resources/runtime.json'):
            raise SystemExit('Preserving a different existing VIR workspace override')
        subprocess.run(['git', 'merge-base', '--is-ancestor', reference, 'HEAD^'], cwd=previous, check=True)
    # The kit performs ordinary native acquisition and SDK installation in a new
    # consumer-owned clone. It preserves existing edits and needs no peer cache.
    run(['bash', kit / 'prepare-local.sh', local], 'local-integration')
    if (git('rev-parse', 'HEAD', cwd=local) != checkpoint['lockSourceCommit'] or
            git('rev-parse', 'HEAD^{tree}', cwd=local) != checkpoint['lockSourceTree'] or
            git('rev-parse', 'HEAD^', cwd=local) != api or
            git('diff', '--name-only', api, 'HEAD', cwd=local) != 'vir-resources/runtime.json' or
            git('status', '--porcelain', cwd=local) or
            json.loads((local / 'vir-resources/runtime.json').read_text()) != lock):
        raise SystemExit('Prepared source differs from the admitted integration checkpoint')
    subprocess.run(['git', 'merge-base', '--is-ancestor', reference, api], cwd=local, check=True)
    installed = local / '.lake/build/vir/sdk'
    metadata = json.loads((installed / 'lean-vir-artifact.json').read_text())
    if metadata['gitCommit'] != api or metadata['gitDirty']:
        raise SystemExit('Installed SDK differs from the selected API source')
    for row in metadata['files']:
        if hashlib.sha256((installed / row['path']).read_bytes()).hexdigest() != row['sha256']:
            raise SystemExit(f'Installed SDK checksum mismatch: {row["path"]}')
    config['packages'] = [row for row in config['packages'] if row['name'] != 'lean_vir'] + [entry]
    override_file.write_text(json.dumps(config, indent=2) + '\n')
    (logs / 'runtime-selection.json').write_text(json.dumps({
        'publicReferenceBase': reference, 'API_SDK_Source': api,
        'lockSourceCommit': checkpoint['lockSourceCommit'],
        'runtimeContentId': receipt['runtime']['contentId'], 'kit': str(kit),
        'source': str(local), 'scope': 'local integration; no public pin or release adoption'}, indent=2) + '\n')
    vir = local
    for key in ['VIR_SDK_URL', 'VIR_SDK_TAG', 'VIR_SDK_COMMIT', 'VIR_SDK_REPO']:
        environment.pop(key, None)
    environment['VIR_SDK_ARCHIVE'] = str(sdk)
    environment['VIR_SDK_EXPECT_COMMIT'] = api

run(['npm', 'ci', '--cache', str(ROOT / '.cache/npm')], 'npm', vir)
run(['lake', 'build', 'lean-run-infoview-assets'], 'assets-build')
run(['lake', 'exe', 'lean-run-infoview-assets'], 'assets')
run(['node', 'scripts/bundle-cast-demo.mjs', str(vir)], 'bundle')
document_module = 'CastEditorFixture' if args.editor_fixture else 'LeanRunInfoview.Demo'
document_path = 'tests/cast/CastEditorFixture.lean' if args.editor_fixture else 'demo/infoview/LeanRunInfoview/Demo.lean'
run(['lake', 'build', '+' + document_module + ':olean'], 'demo-build')
settings = ROOT / '.vscode/settings.json'
values = json.loads(settings.read_text()) if settings.exists() else {}
values['lean4.infoview.autoOpen'] = True
settings.parent.mkdir(exist_ok=True)
settings.write_text(json.dumps(values, indent=2) + '\n')
command = ['code', '--new-window', str(ROOT), '--goto',
           str(ROOT / (document_path + ':13'))]
if args.runtime_kit:
    # A separate VS Code process inherits the SDK selection. Reusing an
    # unrelated running instance does not establish its server environment.
    command[2:2] = ['--user-data-dir', str(logs / ('vscode-' + api[:12]))]
    command = ['env', '-u', 'VIR_SDK_URL', '-u', 'VIR_SDK_TAG', '-u', 'VIR_SDK_COMMIT',
               '-u', 'VIR_SDK_REPO', 'VIR_SDK_ARCHIVE=' + str(sdk),
               'VIR_SDK_EXPECT_COMMIT=' + api] + command
    launcher = logs / 'open-vscode.sh'
    launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\nexec ' + shlex.join(command) + '\n')
    print('Ready: bash', launcher)
else:
    print('Ready:', shlex.join(command))
