"""Strip whitespace from course assets and record the new hashes as approved."""
import hashlib
import json
from pathlib import Path

REASON = '공백만 제거(내용 동일): 파싱 비용과 앱 용량 절감'
INDEX_FILES = {'catalog.json', 'term-periods.json'}


def main() -> None:
    approved_path = Path('test/fixtures/timetable_asset_changes_after_4_0_0.json')
    approved = json.loads(approved_path.read_text(encoding='utf-8'))
    for path in sorted(Path('assets/timetable').glob('*.json')):
        if path.name in INDEX_FILES:
            continue
        raw = path.read_text(encoding='utf-8')
        data = json.loads(raw)
        minified = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        if minified == raw:
            continue
        assert json.loads(minified) == data, path
        path.write_text(minified, encoding='utf-8')
        entry = approved.get(path.as_posix(), {})
        previous = entry.get('reason')
        approved[path.as_posix()] = {
            'sha256': hashlib.sha256(minified.encode()).hexdigest(),
            'reason': f'{previous}; {REASON}' if previous and REASON not in previous else previous or REASON,
        }
    approved_path.write_text(
        json.dumps(approved, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
