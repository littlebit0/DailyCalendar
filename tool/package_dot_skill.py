"""Build the flat ChatGPT .skill archive without credentials or runtime files."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'outputs/dot-skills/dailycalendar-awareness'
FILES = ('SKILL.md', 'connection.md', 'drive-data.md', 'drive_reader.py',
         'keychain_store.py', 'test_drive_reader.py', '.gitignore',
         'plugin.json', 'mcp.json', 'mcp_server.py')


def package():
    if any(p.is_dir() for p in SOURCE.iterdir()):
        raise ValueError('The skill folder must contain files only')
    target = ROOT / 'assets/dot/dailycalendar-awareness.skill'
    target.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(target, 'w', ZIP_DEFLATED) as archive:
        for name in FILES:
            data = (SOURCE / name).read_bytes()
            info = ZipInfo('dailycalendar-awareness/' + name, (2026, 10, 16, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with ZipFile(target) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(FILES)
        assert all(name.count('/') == 1 for name in archive.namelist())
        assert all(archive.read('dailycalendar-awareness/' + name) ==
                   (SOURCE / name).read_bytes() for name in FILES)
    (SOURCE.parent / 'dailycalendar-awareness.zip').write_bytes(target.read_bytes())
    (SOURCE.parent / 'dailycalendar-awareness.skill').write_bytes(target.read_bytes())
    print('Flat .skill and ZIP verified:', len(FILES), 'files, no nested folders')


if __name__ == '__main__':
    package()
