"""Materialize frozen public test inputs, never the ignored research workspace."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tarfile
import tempfile


def prepare(output: Path) -> None:
    root = Path(__file__).resolve().parent.parent / 'test/fixtures/source_audits'
    manifest_bytes = (root / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    fingerprint = hashlib.sha256(manifest_bytes).hexdigest()
    ready = output / '.ready'
    if ready.exists() and ready.read_text() == fingerprint:
        return
    output.mkdir(parents=True, exist_ok=True)
    blobs = output / 'blobs'
    blobs.mkdir(exist_ok=True)
    with tempfile.TemporaryFile() as archive:
        archive_digest = hashlib.sha256()
        for part in manifest['archiveParts']:
            if not re.fullmatch(r'sources-[0-9]{2}\.tar\.xz\.part', part):
                raise ValueError('Unsafe archive part name')
            with (root / part).open('rb') as source:
                while block := source.read(1024 * 1024):
                    archive_digest.update(block)
                    archive.write(block)
        if archive_digest.hexdigest() != manifest['archiveSHA256']:
            raise ValueError('Source fixture archive checksum mismatch')
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode='r:xz', ignore_zeros=True) as packet:
            for member in packet:
                if not member.isfile() or not re.fullmatch(r'[0-9a-f]{64}', member.name):
                    raise ValueError('Unsafe fixture archive entry')
                target = blobs / member.name
                digest = hashlib.sha256()
                with packet.extractfile(member) as source, target.open('wb') as dest:
                    while block := source.read(1024 * 1024):
                        digest.update(block)
                        dest.write(block)
                if digest.hexdigest() != member.name:
                    raise ValueError('Source fixture checksum mismatch')
    for logical, digest in manifest['files'].items():
        path = Path(logical)
        if (not logical.startswith('work/') or path.is_absolute()
                or '..' in path.parts or not re.fullmatch(r'[0-9a-f]{64}', digest)):
            raise ValueError('Unsafe fixture path')
        target = output / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            target.unlink()
        os.link(blobs / digest, target)
    ready.write_text(fingerprint)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    prepare(parser.parse_args().output)
