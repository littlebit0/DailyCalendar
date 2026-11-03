"""Join only real published curriculum codes; preserve scope and conflicts."""
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def prepare():
    original = json.loads((ROOT / 'cuk-current-whole-reconciled-education-next-20261008.json').read_text())
    sources = json.loads((ROOT / 'cuk-current-public-credit-source-tables-20261008.json').read_text())
    credits = collections.defaultdict(list)
    for source in sources:
        for table in source['educationalTables']:
            for row in table:
                if source['scope'] == 'business':
                    if len(row) < 4 or not re.fullmatch(r'\d{5}', row[0]) or not re.fullmatch(r'\d+(?:\.\d+)?', row[3]):
                        continue
                    code, title, raw_credit, raw_hours = row[0], row[1], row[3], None
                    scope = 'Current department-published undergraduate curriculum; explicit cohort/year not printed'
                elif source['scope'] in ['core', 'foundation']:
                    positions = [i for i, value in enumerate(row) if re.fullmatch(r'\d{5}', value)]
                    if len(positions) != 1:
                        continue
                    p = positions[0]
                    if len(row) <= p + 2 or not re.fullmatch(r'\d+(?:\.\d+)?/\d+(?:\.\d+)?', row[p + 2]):
                        continue
                    code, title = row[p], row[p + 1]
                    raw_hours, raw_credit = row[p + 2].split('/')
                    scope = 'School explicitly published2026 undergraduate curriculum page'
                else:
                    # Basic table gives names/credits without canonical codes.
                    # No code reconstructed by title lookup.
                    continue
                credits[code].append({'sourceUrl': source['url'], 'sourceSha256': source['sha256'], 'sourceScope': scope,
                                      'sourceCode': code, 'sourceTitle': title, 'rawCredit': raw_credit, 'rawHours': raw_hours})
    result = dict(original)
    result['courses'] = []
    conflicts = []
    for course in original['courses']:
        row = dict(course)
        evidence = credits.get(course['code'], [])
        values = {float(e['rawCredit']) for e in evidence}
        if len(values) == 1:
            row['credits'] = next(iter(values))
            row['sourceCreditMetadata'] = evidence
        elif len(values) > 1:
            conflicts.append({'code': course['code'], 'section': course['section'], 'actualSourceCreditMetadata': evidence})
        result['courses'].append(row)
    result['productionReady'] = False
    path = ROOT / 'cuk-current-whole-credit-review-next-20261008.json'
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    audit = {'wholeUniqueCodeSection': len(result['courses']), 'creditKnown': sum(c['credits'] is not None for c in result['courses']),
             'creditStillUnknown': sum(c['credits'] is None for c in result['courses']), 'sourceCreditConflicts': conflicts,
             'sourceCurriculumCodes': len(credits), 'scheduled': 0, 'productionReady': False,
             'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
             'limitations': 'No inferred section credit from contact time, name-only basic table, or external school. Business source lacks explicityear; its current-publication scope retained. Ordinary clock/date/exception validation still pending.'}
    (ROOT / 'cuk-current-whole-credit-review-next-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    return result, audit


if __name__ == '__main__':
    _, audit = prepare()
    print(json.dumps(audit, ensure_ascii=False, indent=2))
