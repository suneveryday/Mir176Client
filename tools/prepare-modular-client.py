#!/usr/bin/env python3
"""Package verified client programs and external resources separately, offline."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_guard', ROOT / 'tools/check-release-package.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def write_zip(path, files, metadata, manifest_name='package-manifest.json'):
    metadata = dict(metadata, project='Mir2Classic176', files={n: sha(b) for n, b in files.items()})
    with zipfile.ZipFile(path, 'x', zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        for name, data in files.items():
            archive.writestr(name, data)
        archive.writestr(manifest_name, encode(metadata))


def package_resources(source, target, index_bytes):
    """Read only the canonical static assets, never EXEs or installed settings."""
    index = json.loads(index_bytes)
    files = {}
    seen = set()
    index_sha = sha(index_bytes)
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(target, 'x', zipfile.ZIP_DEFLATED, compresslevel=1) as out:
        for row in index['files']:
            name = row['Path']
            if not guard.safe_name(name) or name.split('/')[0] not in {'Map', 'Resource', 'Wav'} or name.casefold() in seen:
                raise ValueError('invalid resource index')
            seen.add(name.casefold())
            data = original.read(name)
            if len(data) != row['Size'] or sha(data) != row['Sha256']:
                raise ValueError('resource source mismatch: ' + name)
            out.writestr(name, data)
            files[name] = row['Sha256']
        out.writestr('resource-package-manifest.json', encode({
            'project': 'Mir2Classic176', 'kind': 'client-resources',
            'resource_set_id': 'assets-' + index_sha[:12], 'resource_index_sha256': index_sha,
            'origin': index['origin'], 'files': files}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-exe', type=Path, required=True)
    parser.add_argument('--launcher-exe', type=Path, required=True)
    parser.add_argument('--resource-source-zip', type=Path)
    parser.add_argument('--program-only', action='store_true', help='Reuse the unchanged external resource set; package programs only')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.program_only and args.resource_source_zip is None:
        parser.error('--resource-source-zip is required unless --program-only is selected')
    out = args.output
    if out.exists() and any(out.iterdir()):
        raise ValueError('Output must be empty')
    out.mkdir(parents=True, exist_ok=True)
    distribution = json.loads((ROOT / 'distribution.json').read_text())
    inventory = (ROOT / distribution['resources']['index']).read_bytes()
    if sha(inventory) != distribution['resources']['index_sha256']:
        raise ValueError('resource descriptor drift')
    game, launcher = args.game_exe.read_bytes(), args.launcher_exe.read_bytes()
    if sha(game) != distribution['game_client']['exe_sha256'] or sha(launcher) != distribution['launcher']['exe_sha256']:
        raise ValueError('program build mismatch')
    program_files = {'Mir2Classic176.exe': game, 'Mir176Launcher.exe': launcher}
    files = dict(program_files)
    for name in ('README.txt', 'Check-Client.ps1', 'Check-Client.cmd'):
        files[name] = (ROOT / 'client/package' / name).read_bytes()
    files.update({
        'Data/README.txt': b'Keep this resource-scanner directory present. No personal data belongs here.\n',
        'resource-index.json': inventory,
        'client-distribution.json': encode({
            'schema_version': 1, 'project': 'Mir2Classic176',
            'resource_set_id': distribution['resources']['id'],
            'resource_index_sha256': sha(inventory),
            'resource_files': distribution['resources']['files'],
            'resource_bytes': distribution['resources']['bytes'],
            'program_files': {n: sha(b) for n, b in program_files.items()}}),
        'THIRD_PARTY_NOTICES.txt': (
            b'Reconstruction candidate; no new ownership or license is asserted over recovered assets.\n'
            b'Refer to resource-index.json and the matching source tag for origins and copyright headers.\n\n'
            + (ROOT / 'client/current-source/Components/NativeXml/LICENSE.txt').read_bytes()
            + b'\n\n' + (ROOT / 'client/current-source/Source/SceneUI/PXL/License/apache-2.0.txt').read_bytes())})
    program = out / distribution['game_client']['archive']
    write_zip(program, files, {'kind': 'client-program', 'version': distribution['version'],
                            'status': 'pending_runtime_validation', 'resource_set_id': distribution['resources']['id']})
    print(f"PASS program package: {guard.check(program, 'client-program')} files", flush=True)
    if not args.program_only:
        resources = out / distribution['resources']['archive']
        package_resources(args.resource_source_zip, resources, inventory)
        print(f"PASS external resources: {guard.check(resources, 'client-resources')} files", flush=True)


if __name__ == '__main__':
    main()
