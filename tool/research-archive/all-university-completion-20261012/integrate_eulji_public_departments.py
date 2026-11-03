"""Integrate only source-located undergraduate rows; preserve earlier offerings."""
import copy
import hashlib
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
sources = Path('work/full-timetable-audit-20261012/limited-c-public-sources')
path = Path('assets/timetable/eulji-seongnam-2026-2.json')
original = json.loads(path.read_text())
candidate_path = sources / 'eulji-seongnam-integration-candidate.json'
candidate = json.loads(candidate_path.read_text())
ledger = json.loads((sources / 'eulji-integration-ledger.json').read_text())
if not ledger['final'] or ledger['newInserted'] != 200:
    raise SystemExit('Undergraduate reconciliation not final')
existing = {row['sourceId']: row for row in original['courses']}
proposed = {row['sourceId']: row for row in candidate['courses']}
if len(proposed) != len(candidate['courses']) or not existing.keys() <= proposed.keys():
    raise SystemExit('Identity collision or removed original')
for identity, row in existing.items():
    if row != proposed[identity]:
        raise SystemExit('Earlier offering changed')
new = [copy.deepcopy(row) for row in candidate['courses'] if row['sourceId'] not in existing]
for row in new:
    if '대학원' in str(row.get('sourceGrade', '')):
        raise SystemExit('Graduate entry in undergraduate candidate')
    if not row.get('sourceLocator') or not row.get('sourceUrl') or not row['schedules']:
        raise SystemExit('Missing native locator or literal schedule')
    if row['period'] != {'startDate': '2026-09-01', 'endDate': '2026-12-21'}:
        raise SystemExit('Unexpected source semester')
    row['periodEvidence'] = json.loads((sources / 'eulji-period-source-proof.json').read_text())
result = copy.deepcopy(original)
result['courses'].extend(new)
result['sourceRowCount'] = len(result['courses'])
result['additionalSourceUrls'] = candidate['additionalSourceUrls']
result['coverage'] = 'Existing60 public exchange offerings plus200 source-located undergraduate department timetable instances. Graduate2 excluded,48 ambiguous/clinical source instances held; whole university coverage not established. Published combined regular teaching/makeup semester bounds retained; no makeup occurrence dates invented.'
result['completionClaim'] = False
backup = base / 'eulji-before-department-expansion.json'
if not backup.exists():
    backup.write_bytes(path.read_bytes())
path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
orgpath = Path('assets/timetable/organizations/eulji.json')
org = json.loads(orgpath.read_text())
packet = json.loads((sources / 'eulji-new-organizations-packet.json').read_text())
if not packet['final']:
    raise SystemExit('Organizations not final')
orgbackup = base / 'eulji-organizations-before-department-expansion.json'
if not orgbackup.exists():
    orgbackup.write_bytes(orgpath.read_bytes())
labels = {label for row in new for label in row['departments']}
for entry in packet['entries']:
    if entry['sourceLabel'] not in labels:
        raise SystemExit('Organization lacks native query relationship')
    row = copy.deepcopy(entry)
    row.pop('university')
    row.pop('kind')
    row['collegeKnown'] = row['college'] is not None
    row['collegeOnlyEligible'] = False
    row['affiliationStatus'] = 'verified'
    row['sourceFile'] = packet['sourceHeadingsFile']
    org['mappings'].append(row)
orgpath.write_text(json.dumps(org, ensure_ascii=False, indent=2) + '\n')
receipt = {'candidateSha256': hashlib.sha256(candidate_path.read_bytes()).hexdigest(), 'previousOfferingsPreserved': len(existing), 'additionalUndergraduateOfferings': len(new), 'currentOfferings': len(result['courses']), 'graduateInstancesExcluded': 2, 'heldInstances': 48, 'newMappings': len(packet['entries']), 'userApprovedDualAffiliation': '시각디자인전공: 미래융합대학 and 전공통합학부, one source offering', 'verificationPending': True, 'wholeUniversityCompletion': False}
(base / 'eulji-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(receipt)
