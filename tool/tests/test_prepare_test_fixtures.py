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
