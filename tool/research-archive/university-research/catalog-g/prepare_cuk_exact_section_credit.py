"""Add dated same-term official credits by exact code/section/title, not time."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def prepare():
    before = json.loads((ROOT / 'cuk-current-whole-credit-review-next-20261008.json').read_text())
    source = json.loads((ROOT / 'cuk-current2026-2-exchange-credit-crosscheck-20261008.json').read_text())
    evidence = {(r['code'], r['section'], r['title']): r for r in source['matches']}
    result = copy.deepcopy(before)
    conflicts = []
    added = 0
    for course in result['courses']:
        row = evidence.get((course['code'], course['section'], course['title']))
        if row is None:
            continue
        credit = float(row['sourceCredits'])
        if course['credits'] is not None and course['credits'] != credit:
            conflicts.append({'code': course['code'], 'section': course['section'],
                              'currentCredit': course['credits'], 'sourceCredit': credit})
            continue
        if course['credits'] is None:
            course['credits'] = credit
            course['sourceCreditMetadata'] = [{
                'sourceUrl': source['sourceAttachmentUrl'],
                'sourceSha256': source['sourceSha256'],
                'sourceScope': 'Official 2026-2 exchange list dated2026-07-10; historical same-term credit only',
                'sourceCode': course['code'], 'sourceSection': course['section'],
                'sourceTitle': course['title'], 'rawCredit': row['sourceCredits'],
            }]
            added += 1
    path = ROOT / 'cuk-current-whole-exact-section-credit-next-20261008.json'
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    audit = {'wholeCount': len(result['courses']), 'directCurriculumCredits': 278,
             'exactSectionCreditsAdded': added, 'creditsKnown': sum(c['credits'] is not None for c in result['courses']),
             'creditsUnknown': sum(c['credits'] is None for c in result['courses']),
             'creditConflicts': conflicts, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
             'policy': 'Preserve current code/section/title/class/department/room/time/remarks; old time and old membership never overwrite current.',
             'scheduled': 0, 'productionReady': False}
    (ROOT / 'cuk-current-whole-exact-section-credit-next-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    return result, audit


if __name__ == '__main__':
    _, audit = prepare()
    print(json.dumps(audit, ensure_ascii=False))
