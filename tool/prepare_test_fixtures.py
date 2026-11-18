"""Materialize frozen public test inputs, never the ignored research workspace."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tarfile
import tempfile


def _replace_link(blob: Path, target: Path) -> None:
    """Point target at blob without truncating or briefly removing a file
    another test isolate may be reading."""
    temporary = target.with_name(f'.{target.name}.link')
    if temporary.exists():
        temporary.unlink()
    os.link(blob, temporary)
    os.replace(temporary, target)


def prepare(output: Path) -> None:
    root = Path(__file__).resolve().parent.parent / 'test/fixtures/source_audits'
    manifest_bytes = (root / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    fingerprint = hashlib.sha256(manifest_bytes).hexdigest()
    for logical, digest in manifest['files'].items():
        path = Path(logical)
        if (not logical.startswith('work/') or path.is_absolute()
                or '..' in path.parts or not re.fullmatch(r'[0-9a-f]{64}', digest)):
            raise ValueError('Unsafe fixture path')
    ready = output / '.ready'
    blobs = output / 'blobs'
    missing = {logical: digest for logical, digest in manifest['files'].items()
               if not (output / logical).is_file()}
    if ready.exists() and ready.read_text() == fingerprint:
        if not missing:
            return
        # A cleaner removed some files but kept their blobs: relink only those.
        if all((blobs / digest).is_file() for digest in missing.values()):
            for logical, digest in missing.items():
                (output / logical).parent.mkdir(parents=True, exist_ok=True)
                _replace_link(blobs / digest, output / logical)
            return
    output.mkdir(parents=True, exist_ok=True)
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
                # Write a new file and swap it in, so readers of an existing
                # blob (hard-linked into work/) never see it truncated.
                temporary = blobs / f'.{member.name}.part'
                digest = hashlib.sha256()
                with packet.extractfile(member) as source, temporary.open('wb') as dest:
                    while block := source.read(1024 * 1024):
                        digest.update(block)
                        dest.write(block)
                if digest.hexdigest() != member.name:
                    temporary.unlink()
                    raise ValueError('Source fixture checksum mismatch')
                os.replace(temporary, blobs / member.name)
    for logical, digest in manifest['files'].items():
        target = output / logical
        target.parent.mkdir(parents=True, exist_ok=True)
        _replace_link(blobs / digest, target)
    ready.write_text(fingerprint)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    prepare(parser.parse_args().output)
