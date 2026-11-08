"""Strip insignificant JSON whitespace from bundled timetable assets.

Covers assets/timetable/*.json and assets/timetable/organizations/*.json and
records the new hashes as approved in the release integrity fixture. Only
whitespace outside strings is removed, so every key, number and string token
keeps its original spelling. Re-running leaves compact files unchanged.

    python3 tool/timetable/minify_assets.py           # rewrite and record
    python3 tool/timetable/minify_assets.py --check   # fail if any file is not compact
"""
import hashlib
import json
import sys
from decimal import Decimal
from pathlib import Path

REASON = '공백만 제거(내용 동일): 파싱 비용과 앱 용량 절감'
# Index files are pruned by design and not hash-checked by the integrity test.
INDEX_FILES = {'catalog.json', 'term-periods.json'}
APPROVED_PATH = Path('test/fixtures/timetable_asset_changes_after_4_0_0.json')
WHITESPACE = ' \t\n\r'


def strip_whitespace(raw: str) -> str:
    out = []
    in_string = escaped = False
    for ch in raw:
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
            out.append(ch)
        elif ch not in WHITESPACE:
            out.append(ch)
    return ''.join(out)


def exact(text: str):
    # Pairs keep key order and duplicates; Decimal keeps number precision.
    return json.loads(text, object_pairs_hook=list, parse_float=Decimal, parse_int=Decimal)


def asset_paths():
    root = Path('assets/timetable')
    return sorted([*root.glob('*.json'), *root.glob('organizations/*.json')])


def main() -> None:
    check_only = '--check' in sys.argv[1:]
    approved = json.loads(APPROVED_PATH.read_text(encoding='utf-8'))
    stale = []
    for path in asset_paths():
        raw = path.read_text(encoding='utf-8')
        minified = strip_whitespace(raw)
        if minified == raw:
            continue
        if check_only:
            stale.append(path.as_posix())
            continue
        assert exact(minified) == exact(raw), path
        path.write_text(minified, encoding='utf-8')
        if path.name in INDEX_FILES:
            continue
        entry = approved.get(path.as_posix(), {})
        previous = entry.get('reason')
        approved[path.as_posix()] = {
            'sha256': hashlib.sha256(minified.encode()).hexdigest(),
            'reason': f'{previous}; {REASON}' if previous and REASON not in previous else previous or REASON,
        }
    if check_only:
        if stale:
            sys.exit('not compact:\n' + '\n'.join(stale))
        return
    APPROVED_PATH.write_text(
        json.dumps(approved, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
