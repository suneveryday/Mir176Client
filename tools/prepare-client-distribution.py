#!/usr/bin/env python3
"""Remove local diagnostic paths from an unsigned Delphi PE without resizing it."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def redact(data, source_prefix):
    prefix = source_prefix.encode("utf-16le")
    if not source_prefix or not source_prefix.endswith(("/", "\\")):
        raise ValueError("source prefix must end in a directory separator")
    result = bytearray(data)
    changes = []
    start = 0
    while True:
        offset = data.find(prefix, start)
        if offset < 0:
            break
        if offset < 12:
            raise ValueError("unrecognized diagnostic string")
        codepage, element_size, refcount, length = struct.unpack_from("<HHiI", data, offset - 12)
        end = offset + length * 2
        if (codepage, element_size, refcount) != (1200, 2, -1):
            raise ValueError("match is not a constant Delphi UnicodeString")
        if not len(source_prefix) <= length <= 4096 or data[end:end + 2] != b"\0\0":
            raise ValueError("invalid UnicodeString boundary")
        original = data[offset:end].decode("utf-16le")
        relative = original[len(source_prefix):]
        if not relative or ":" in relative or relative.startswith(("/", "\\")):
            raise ValueError("invalid relative diagnostic path")
        replacement = relative.ljust(length).encode("utf-16le")
        if len(replacement) != end - offset:
            raise ValueError("diagnostic path cannot be resized")
        result[offset:end] = replacement
        changes.append({"offset": offset, "characters": length, "relative_path": relative})
        start = end + 2
    if not changes:
        raise ValueError("no recognized source path constants")
    return bytes(result), changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--source-prefix", required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    original = args.input.read_bytes()
    if sha256(original) != args.expected_sha256:
        raise ValueError("input build hash mismatch")
    if args.output.exists() or args.report.exists():
        raise ValueError("output already exists")
    if original[:2] != b"MZ":
        raise ValueError("input is not a PE")
    pe = struct.unpack_from("<I", original, 0x3C)[0]
    if original[pe:pe + 4] != b"PE\0\0":
        raise ValueError("invalid PE header")
    optional = pe + 24
    if struct.unpack_from("<H", original, optional)[0] != 0x10B:
        raise ValueError("expected Win32 PE")
    # Certificate directory is entry 4; signed inputs must be rebuilt instead.
    if struct.unpack_from("<II", original, optional + 96 + 4 * 8) != (0, 0):
        raise ValueError("refusing to modify a signed PE")
    output, changes = redact(original, args.source_prefix)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    report = {
        "operation": "same-length-diagnostic-UnicodeString-path-redaction",
        "input_sha256": sha256(original),
        "output_sha256": sha256(output),
        "bytes": len(output),
        "changed_bytes": sum(a != b for a, b in zip(original, output)),
        "strings": changes,
        "runtime_validation": "pending_runtime_validation",
        "note": "Only diagnostic string payloads changed; original compiler build is preserved separately."
    }
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS diagnostic strings={len(changes)} output_sha256={report['output_sha256']}")


if __name__ == "__main__":
    main()
