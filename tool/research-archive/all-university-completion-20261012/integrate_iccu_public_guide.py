import copy
import hashlib
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
source = Path('work/full-timetable-audit-20261012/limited-c-public-sources')
target = Path('assets/timetable/iccu-songdo-2026-2.json')
candidate_path = source / 'iccu-merged-schema2-candidate.json'
candidate = json.loads(candidate_path.read_text())
original = json.loads(target.read_text())
existing = {row['sourceId']: row for row in original['courses']}
proposed = {row['sourceId']: row for row in candidate['courses']}
if len(proposed) != len(candidate['courses']):
    raise SystemExit('Duplicate candidate identity')
if not existing.keys() <= proposed.keys():
    raise SystemExit('Candidate deletes a newer native record')
for identity, row in existing.items():
    if row != proposed[identity]:
        raise SystemExit(f'Candidate changes newer native row {identity}')
result = copy.deepcopy(original)
new = [copy.deepcopy(row) for row in candidate['courses'] if row['sourceId'] not in existing]
for row in new:
    if not row['courseCode'] or not row['section'] or not row.get('nativeSourceRows'):
        raise SystemExit('Additional guide row lacks native code/section evidence')
    row['sourceSha256'] = candidate['sourceSha256']
    row['sourcePublishedDate'] = '2026-07-30'
    row['periodEvidence'] = {'sourceUrl': candidate['sourceUrl'], 'pdfPage': 54, 'printedPage': 44, 'basis': 'Official week-phase operating date table; published weekly classes only, no generated occurrence dates.'}
result['courses'].extend(new)
result['schemaVersion'] = 2
result['sourceRowCount'] = len(result['courses'])
result['additionalSourceUrls'] = candidate['additionalSourceUrls'] + [candidate['sourceUrl']]
result['supplementarySource'] = {'url': candidate['sourceUrl'], 'sha256': candidate['sourceSha256'], 'publishedDate': '2026-07-30', 'noticeUrl': candidate['sourcePageUrl'], 'addedOfferings': len(new)}
result['coverage'] = 'Existing latest nursing/ELPIS source preserved in full; additional official undergraduate registration-guide offerings with literal native codes/sections. Unconfirmed clocks/clinical rotations remain unrecognized or held. Whole-university completion not established.'
result['completionClaim'] = False
backup = base / 'iccu-before-public-guide.json'
if not backup.exists():
    backup.write_bytes(target.read_bytes())
target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
receipt = {'candidateSha256': hashlib.sha256(candidate_path.read_bytes()).hexdigest(), 'previousOfferingsPreserved': len(existing), 'additionalOfferings': len(new), 'currentOfferings': len(result['courses']), 'retainedNewerClosureConflicts': 3, 'sourceClosureCodesExcludedFromGuide': 7, 'verificationPending': True, 'wholeUniversityCompletion': False}
(base / 'iccu-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(receipt))
