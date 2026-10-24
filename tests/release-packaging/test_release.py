"""Release guards: hostile archives, manifest drift and diagnostic-only redaction."""
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


redaction = load("redaction", "prepare-client-distribution.py")
guard = load("guard", "check-release-package.py")
modular = load("modular", "prepare-modular-client.py")


class ResourcePackageTests(unittest.TestCase):
    def test_selects_only_static_assets_never_program_or_settings(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            source, target = root / 'source.zip', root / 'resources.zip'
            asset = b'map fixture'
            index = {'project': 'Mir2Classic176', 'origin': 'test fixture', 'files': [
                {'Path': 'Map/0.map', 'Size': len(asset), 'Sha256': hashlib.sha256(asset).hexdigest()}]}
            with zipfile.ZipFile(source, 'w') as z:
                z.writestr('Map/0.map', asset)
                z.writestr('Mir2Classic176.exe', b'old executable excluded')
                z.writestr('Mir2Classic176.ini', b'local settings excluded')
            modular.package_resources(source, target, json.dumps(index).encode())
            with zipfile.ZipFile(target) as z:
                self.assertEqual(set(z.namelist()), {'Map/0.map', 'resource-package-manifest.json'})
                manifest = json.loads(z.read('resource-package-manifest.json'))
                self.assertEqual(manifest['files'], {'Map/0.map': index['files'][0]['Sha256']})

    def test_missing_corrupt_unsafe_and_case_duplicate_assets_fail(self):
        for failure in ('missing', 'corrupt', 'unsafe', 'duplicate'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as d:
                root = Path(d)
                source, target = root / 'source.zip', root / 'resources.zip'
                row = {'Path': 'Map/0.map', 'Size': 7, 'Sha256': hashlib.sha256(b'fixture').hexdigest()}
                rows = [row]
                if failure == 'unsafe': row['Path'] = 'Map/../outside'
                if failure == 'duplicate': rows.append(dict(row, Path='map/0.MAP'))
                with zipfile.ZipFile(source, 'w') as z:
                    if failure != 'missing': z.writestr('Map/0.map', b'changed' if failure == 'corrupt' else b'fixture')
                with self.assertRaises((ValueError, KeyError)):
                    modular.package_resources(source, target, json.dumps({'origin': 'test', 'files': rows}).encode())


class RedactionTests(unittest.TestCase):
    def test_only_valid_constant_payload_changes(self):
        prefix = "Q:" + chr(92) + "build" + chr(92)
        value = prefix + "Source" + chr(92) + "Example.pas"
        header = struct.pack("<HHiI", 1200, 2, -1, len(value))
        original = b"untouched" + header + value.encode("utf-16le") + b"\0\0suffix"
        result, changes = redaction.redact(original, prefix)
        self.assertEqual(len(original), len(result))
        self.assertEqual(result[:21], original[:21])
        self.assertEqual(result[-8:], original[-8:])
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0]["relative_path"], "Source" + chr(92) + "Example.pas")
        self.assertNotIn(prefix.encode("utf-16le"), result)

    def test_rejects_arbitrary_binary_match(self):
        prefix = "Q:/build/"
        with self.assertRaises(ValueError):
            redaction.redact(b"x" * 12 + prefix.encode("utf-16le") + b"\0\0", prefix)

    def test_requires_a_real_match(self):
        with self.assertRaises(ValueError):
            redaction.redact(b"unchanged", "Q:/build/")


class ArchiveTests(unittest.TestCase):
    def test_launcher_archive_rejects_game_and_local_configuration(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "launcher.zip"
            files = {"Mir176Launcher.exe": b"MZfixture", "README.txt": b"Launcher only", "launcher-build.json": b"{}"}
            def write():
                with zipfile.ZipFile(path, "w") as z:
                    for name, data in files.items():
                        z.writestr(name, data)
                    z.writestr("package-manifest.json", json.dumps({"project": "Mir2Classic176", "files": {
                        n: hashlib.sha256(b).hexdigest() for n, b in files.items()}}))
            write()
            self.assertEqual(guard.check(path, "launcher"), 3)
            files["Mir2Classic176.exe"] = b"excluded game"
            write()
            with self.assertRaisesRegex(ValueError, "standalone launcher"):
                guard.check(path, "launcher")
            del files["Mir2Classic176.exe"]
            files["Mir2Classic176.ini"] = b"[Server]"
            write()
            with self.assertRaisesRegex(ValueError, "standalone launcher"):
                guard.check(path, "launcher")

    def archive(self, directory, extra=None, manifest_change=None):
        files = {"Mir2Classic176.exe": b"MZfixture", "Configure-Classic.ps1": b"# offline configure\n",
                 "Data/README.txt": b"Keep this directory.\n"}
        files.update(extra or {})
        manifest = {"project": "Mir2Classic176", "version": "0.1.5", "files": {
            n: hashlib.sha256(b).hexdigest() for n, b in files.items()}}
        if manifest_change:
            manifest_change(manifest)
        path = Path(directory) / "candidate.zip"
        with zipfile.ZipFile(path, "w") as z:
            for name, data in files.items():
                z.writestr(name, data)
            z.writestr("package-manifest.json", json.dumps(manifest))
        return path

    def test_clean_complete_manifest_passes(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(guard.check(self.archive(d), "client"), 3)

    def test_hash_drift_fails(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.archive(d, manifest_change=lambda m: m["files"].update({"Mir2Classic176.exe": "0" * 64}))
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                guard.check(path, "client")

    def test_undeclared_file_fails(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.archive(d, manifest_change=lambda m: m["files"].pop("Data/README.txt"))
            with self.assertRaisesRegex(ValueError, "coverage"):
                guard.check(path, "client")

    def test_install_configuration_fails(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.archive(d, {"Mir2Classic176.ini": b"[Server]\n"})
            with self.assertRaisesRegex(ValueError, "unexpected client"):
                guard.check(path, "client")

    def test_modular_kinds_reject_incomplete_or_mixed_packages(self):
        distribution = json.loads((ROOT / 'distribution.json').read_text())
        for kind in ('client-program', 'client-resources'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as d:
                path = Path(d) / 'mixed.zip'
                manifest_name = 'resource-package-manifest.json' if kind == 'client-resources' else 'package-manifest.json'
                files = {'Mir2Classic176.exe': b'executable', 'Map/0.map': b'map'}
                with zipfile.ZipFile(path, 'w') as z:
                    for name, data in files.items(): z.writestr(name, data)
                    z.writestr(manifest_name, json.dumps({'project': 'Mir2Classic176',
                        'resource_set_id': distribution['resources']['id'],
                        'files': {n: hashlib.sha256(b).hexdigest() for n, b in files.items()}}))
                with self.assertRaisesRegex(ValueError, 'coverage mismatch'):
                    guard.check(path, kind)

    def test_unsafe_name_symlink_and_case_collision(self):
        for bad in ("../outside", "/outside", "Q:/outside", "Map/../outside", "Map\\outside"):
            self.assertFalse(guard.safe_name(bad))
        with tempfile.TemporaryDirectory() as d:
            path = self.archive(d)
            with zipfile.ZipFile(path, "a") as z:
                entry = zipfile.ZipInfo("Map/link")
                entry.create_system = 3
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                z.writestr(entry, "target")
            with self.assertRaisesRegex(ValueError, "symlink"):
                guard.check(path, "client")
        with tempfile.TemporaryDirectory() as d:
            path = self.archive(d, {"data/readme.TXT": b"duplicate"})
            with self.assertRaisesRegex(ValueError, "duplicate"):
                guard.check(path, "client")

    def test_utf16_local_diagnostic_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            marker = ("D" + ":" + chr(92) + "local-build" + chr(92)).encode("utf-16le")
            path = self.archive(d, {"Mir2Classic176.exe": b"MZ" + marker})
            with self.assertRaisesRegex(ValueError, "privacy rejection"):
                guard.check(path, "client")

    def test_vendor_exception_cannot_be_used_by_changed_binary(self):
        sample = b"D" + b":" + bytes([92]) + b"a" + bytes([92]) + b"fixture"
        self.assertIn("personal-workspace", guard.content_reasons(
            "Collections.Pooled.dll", sample, hashlib.sha256(sample).hexdigest()))
        marker = ("-----BEGIN " + "PRIVATE KEY-----").encode()
        self.assertIn("private-key", guard.content_reasons(
            "MySqlConnector.dll", marker, hashlib.sha256(marker).hexdigest()))


if __name__ == "__main__":
    unittest.main()
