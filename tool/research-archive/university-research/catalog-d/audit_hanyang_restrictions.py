"""Audit acquired public course restriction details against whole catalog flags."""
from pathlib import Path
import json
from collections import Counter

p = Path(__file__).parent
expected = {}
for campus in ['seoul', 'seoul-medicine', 'erica']:
    for row in json.loads((p / f'hanyang-2026-2-{campus}-all.json').read_text())['records']:
        if str(row['isuJehanYn']).startswith('O'):
            expected[row['suupNo']] = campus
acquired = {}
empty = []
mismatched = []
identity_not_echoed = []
rows_total = 0
for course, campus in expected.items():
    target = p / 'hanyang-2026-2-restrictions-raw' / f'{course}.json'
    if not target.exists():
        continue
    data = json.loads(target.read_text())
    if 'exception' in data:
        raise RuntimeError('Acquired response contains exception')
    sets = {}
    for key, blocks in data.items():
        if not key.startswith('DS_'):
            continue
        sets[key] = [row for block in blocks for row in block.get('list', [])]
    rows = [row for values in sets.values() for row in values]
    if not rows:
        empty.append(course)
    if any('suupNo' not in row for row in rows):
        identity_not_echoed.append(course)
    if any((row.get('suupNo') is not None and str(row['suupNo']) != course)
           or (row.get('suupYear') is not None and str(row['suupYear']) != '2026')
           or (row.get('suupTerm') is not None and str(row['suupTerm']) != '20') for row in rows):
        mismatched.append(course)
    acquired[course] = dict(campus=campus, datasets=sets)
    rows_total += len(rows)
missing = sorted(set(expected) - set(acquired))
audit = dict(expectedClasses=len(expected), acquiredClasses=len(acquired), rows=rows_total,
             missing=missing, empty=empty, mismatched=mismatched,
             identityNotEchoed=identity_not_echoed,
             campusCounts=dict(Counter(v['campus'] for v in acquired.values())),
             restrictionAcquisitionComplete=not missing and not empty and not mismatched,
             productionActivationComplete=False)
(p / 'hanyang-2026-2-restrictions-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2))
(p / 'hanyang-2026-2-restrictions-all.json').write_text(json.dumps(acquired, ensure_ascii=False, indent=2))
print({k: v for k, v in audit.items() if k not in ['missing', 'empty', 'mismatched', 'identityNotEchoed']})
print('missing', len(missing), 'empty', len(empty), 'mismatched', len(mismatched))
