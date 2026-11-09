"""Prepare the optional infoview demo from this worktree's selected dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime-kit', type=Path,
                    help='qualified local VIR lock checkpoint kit; installs a Lake package override')
parser.add_argument('--cast-source-kit', type=Path, help='frozen Cast source-only qualification handoff')
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
    if (selected['rev'] != record['baseCommit'] or
            hashlib.sha256(archive.read_bytes()).hexdigest() != record['archiveSha256'] or
            hashlib.sha256((handoff / 'source.patch').read_bytes()).hexdigest() != record['patchSha256']):
        raise SystemExit('The frozen Cast source handoff does not match its recorded base/hash')
    target = logs / ('cast-source-' + record['patchSha256'][:12])
    # Compare a retained source copy before reuse; never overwrite source edits.
    with tarfile.open(archive) as stream:
        if target.exists():
            for member in stream.getmembers():
                if member.isfile():
                    path = target / member.name
                    if not path.is_file() or path.read_bytes() != stream.extractfile(member).read():
                        raise SystemExit('Preserving edits in the frozen Cast source copy')
        else:
            target.mkdir()
            stream.extractall(target, filter='data')
    source = target / 'source'
    for row in record['files']:
        if hashlib.sha256((source / row['path']).read_bytes()).hexdigest() != row['sha256']:
            raise SystemExit('Frozen Cast source file checksum mismatch')
    override_file = ROOT / '.lake/package-overrides.json'
    config = json.loads(override_file.read_text()) if override_file.exists() else {'version': '1.3.0', 'packages': []}
    entry = {'name': '«verso-cast»', 'type': 'path', 'dir': str(source), 'inherited': False,
             'configFile': 'lakefile.lean', 'manifestFile': 'lake-manifest.json'}
    existing = [row for row in config['packages'] if row['name'] == '«verso-cast»']
    if existing not in ([], [entry]):
        raise SystemExit('Preserving a different existing Cast package override')
    config['packages'] = [row for row in config['packages'] if row['name'] != '«verso-cast»'] + [entry]
    override_file.write_text(json.dumps(config, indent=2) + '\n')

vir = ROOT / '.lake/packages/lean_vir'
if args.runtime_kit:
    checkpoint_dir = args.runtime_kit.resolve(strict=True)
    checkpoint = json.loads((checkpoint_dir / 'CHECKPOINT.json').read_text())
    kit = (checkpoint_dir.parent / Path(checkpoint['matchedArtifactKit']).name).resolve(strict=True)
    receipt = json.loads((kit / 'ARTIFACTS.json').read_text())
    selected = next(row for row in json.loads((ROOT / 'lake-manifest.json').read_text())['packages']
                    if row['name'] == 'lean_vir')
    if selected['rev'] != receipt['source'] or git('rev-parse', 'HEAD', cwd=vir) != receipt['source']:
        raise SystemExit('The local runtime kit must match the exact selected VIR revision')
    if (checkpoint['API_SDK_Source'] != receipt['source'] or
            checkpoint['onlyChangedPath'] != 'vir-resources/runtime.json'):
        raise SystemExit('Expected the qualified lock-only checkpoint')
    bundle = checkpoint_dir / checkpoint['bundle']
    if hashlib.sha256(bundle.read_bytes()).hexdigest() != checkpoint['bundleSha256']:
        raise SystemExit('Local lock checkpoint checksum mismatch')
    pack = kit / receipt['runtime']['pack']
    data = pack.read_bytes()
    if (len(data) != receipt['runtime']['byteLength'] or
            hashlib.sha256(data).hexdigest() != receipt['runtime']['sha256']):
        raise SystemExit('Local runtime kit checksum mismatch')
    lock = json.loads((kit / 'runtime.local.json').read_text())
    expected_lock = {'schemaVersion': 1, 'contentId': receipt['runtime']['contentId'],
                     'source': 'build/local-runtime/' + receipt['runtime']['contentId'] + '.virres'}
    if lock != expected_lock:
        raise SystemExit('Expected the qualified relative local runtime selection')
    # Keep source pins portable. This isolated checkpoint differs only in its
    # local resource lock; Lake's ordinary workspace override also applies to VS Code
    # and nested test/build commands. Never modify .lake/packages source files.
    local = logs / ('lean-vir-' + checkpoint['lockSourceCommit'][:12])
    override_file = ROOT / '.lake/package-overrides.json'
    override = {'version': '1.3.0', 'packages': [{'name': 'lean_vir', 'type': 'path', 'dir': str(local),
                 'inherited': False, 'configFile': 'lakefile.lean',
                 'manifestFile': 'lake-manifest.json'}]}
    existing = json.loads(override_file.read_text()) if override_file.exists() else override
    selected_overrides = [row for row in existing['packages'] if row['name'] == 'lean_vir']
    had_vir_override = bool(selected_overrides)
    if selected_overrides not in ([], override['packages']):
        raise SystemExit('Preserving a different existing VIR package override')
    override['packages'] = [row for row in existing['packages'] if row['name'] != 'lean_vir'] + override['packages']
    if not local.exists():
        run(['git', 'clone', '--no-hardlinks', '--no-checkout', str(vir), str(local)], 'local-clone')
        run(['git', 'checkout', '--detach', receipt['source']], 'local-checkout', cwd=local)
    if git('diff', '--name-only', cwd=local) or git('diff', '--cached', '--name-only', cwd=local):
        raise SystemExit('Preserving edits in the local source clone')
    run(['git', 'fetch', str(bundle), 'refs/heads/' + checkpoint['localBranch']], 'local-lock-fetch', cwd=local)
    run(['git', 'checkout', '--detach', checkpoint['lockSourceCommit']], 'local-lock-checkout', cwd=local)
    if (git('rev-parse', 'HEAD^', cwd=local) != receipt['source'] or
            git('diff', '--name-only', receipt['source'], 'HEAD', cwd=local) != 'vir-resources/runtime.json' or
            json.loads((local / 'vir-resources/runtime.json').read_text()) != lock):
        raise SystemExit('The local checkpoint is not the admitted lock-only source')
    # The selected native tool verifies framing, payload hashes, CID and compiler
    # profile before installing this input at the lock's safe relative path.
    run(['lake', 'build', '@lean_vir/vir_resource_pack'], 'resource-tool')
    tool_owner = local if had_vir_override else vir
    destination = local / lock['source']
    destination.parent.mkdir(parents=True, exist_ok=True)
    run([tool_owner / '.lake/build/bin/vir_resource_pack', 'acquire',
         local / 'vir-resources/compatibility.json', lock['contentId'], pack,
         destination, destination], 'local-runtime')
    override_file.write_text(json.dumps(override, indent=2) + '\n')
    vir = local

run(['npm', 'ci', '--cache', str(ROOT / '.cache/npm')], 'npm', vir)
run(['lake', 'build', 'lean-run-infoview-assets'], 'assets-build')
run(['lake', 'exe', 'lean-run-infoview-assets'], 'assets')
run(['node', 'scripts/bundle-cast-demo.mjs', str(vir)], 'bundle')
run(['lake', 'build', '+LeanRunInfoview.Demo:olean'], 'demo-build')
settings = ROOT / '.vscode/settings.json'
values = json.loads(settings.read_text()) if settings.exists() else {}
values['lean4.infoview.autoOpen'] = True
settings.parent.mkdir(exist_ok=True)
settings.write_text(json.dumps(values, indent=2) + '\n')
print('Ready: code --new-window', ROOT, '--goto', ROOT / 'demo/infoview/LeanRunInfoview/Demo.lean:13')
