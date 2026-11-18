import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'fixture_preparer', Path(__file__).parents[1] / 'prepare_test_fixtures.py')
preparer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preparer)


class FixturePreparationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixture = self.root / 'test/fixtures/source_audits'
        self.fixture.mkdir(parents=True)
        self.body = b'{"public":true}'
        self.digest = hashlib.sha256(self.body).hexdigest()
        self.output = self.root / 'cache'

    def packet(self, member=None, logical='work/public-source.json'):
        part = self.fixture / 'sources-00.tar.xz.part'
        with tarfile.open(part, 'w:xz') as archive:
            info = tarfile.TarInfo(member or self.digest)
            info.size = len(self.body)
            archive.addfile(info, io.BytesIO(self.body))
        (self.fixture / 'manifest.json').write_text(json.dumps({
            'archiveSHA256': hashlib.sha256(part.read_bytes()).hexdigest(),
            'archiveParts': [part.name], 'files': {logical: self.digest},
        }))

    def prepare(self):
        with patch.object(preparer, '__file__', str(self.root / 'tool/preparer.py')):
            preparer.prepare(self.output)

    def test_byte_identity_and_repeat_preparation(self):
        self.packet()
        self.prepare()
        self.prepare()
        self.assertEqual((self.output / 'work/public-source.json').read_bytes(), self.body)
        self.assertTrue((self.output / '.ready').exists())

    def test_missing_file_is_recreated_even_when_ready_marker_matches(self):
        self.packet()
        self.prepare()
        (self.output / 'work/public-source.json').unlink()
        self.prepare()
        self.assertEqual((self.output / 'work/public-source.json').read_bytes(), self.body)

    def test_reextraction_never_truncates_a_file_in_use(self):
        bodies = {'work/kept.json': b'{"kept":true}', 'work/lost.json': b'{"lost":true}'}
        digests = {k: hashlib.sha256(v).hexdigest() for k, v in bodies.items()}
        part = self.fixture / 'sources-00.tar.xz.part'
        with tarfile.open(part, 'w:xz') as archive:
            for logical, body in bodies.items():
                info = tarfile.TarInfo(digests[logical])
                info.size = len(body)
                archive.addfile(info, io.BytesIO(body))
        (self.fixture / 'manifest.json').write_text(json.dumps({
            'archiveSHA256': hashlib.sha256(part.read_bytes()).hexdigest(),
            'archiveParts': [part.name], 'files': digests,
        }))
        self.prepare()
        kept = self.output / 'work/kept.json'
        # Losing a file and its blob forces re-extraction. Another isolate may
        # read kept.json at any moment of it, so record what it would see.
        (self.output / 'work/lost.json').unlink()
        (self.output / 'blobs' / digests['work/lost.json']).unlink()
        seen = []
        original = tarfile.TarFile.extractfile

        def observed(packet, member):
            stream = original(packet, member)
            read = stream.read

            def read_and_observe(*args):
                seen.append(kept.read_bytes())
                return read(*args)

            stream.read = read_and_observe
            return stream

        with patch.object(tarfile.TarFile, 'extractfile', observed):
            self.prepare()
        self.assertTrue(seen)
        self.assertTrue(all(body == bodies['work/kept.json'] for body in seen))
        for logical, body in bodies.items():
            self.assertEqual((self.output / logical).read_bytes(), body)

    def test_missing_link_is_restored_from_its_blob_without_extraction(self):
        self.packet()
        self.prepare()
        (self.output / 'work/public-source.json').unlink()
        with patch.object(preparer.tarfile, 'open', side_effect=AssertionError('extracted')):
            self.prepare()
        self.assertEqual((self.output / 'work/public-source.json').read_bytes(), self.body)

    def test_archive_tampering_is_rejected(self):
        self.packet()
        with (self.fixture / 'sources-00.tar.xz.part').open('ab') as f:
            f.write(b'tampered')
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            self.prepare()
        self.assertFalse((self.output / '.ready').exists())

    def test_archive_traversal_is_rejected(self):
        self.packet(member='../outside')
        with self.assertRaisesRegex(ValueError, 'Unsafe fixture archive entry'):
            self.prepare()
        self.assertFalse((self.root / 'outside').exists())

    def test_logical_traversal_is_rejected(self):
        self.packet(logical='work/../../outside')
        with self.assertRaisesRegex(ValueError, 'Unsafe fixture path'):
            self.prepare()
        self.assertFalse((self.root / 'outside').exists())

    def test_source_byte_tampering_is_rejected(self):
        self.packet(member='0' * 64)
        with self.assertRaisesRegex(ValueError, 'Source fixture checksum mismatch'):
            self.prepare()
        self.assertFalse((self.output / '.ready').exists())


if __name__ == '__main__':
    unittest.main()
