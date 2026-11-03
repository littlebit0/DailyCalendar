"""Current ownership and applied-vs-verified checkpoint, never a completion claim."""
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
scope = json.loads((base / 'coverage-start.json').read_text())
a = json.loads((base / 'program-groups-a.json').read_text())
c = json.loads((base / 'program-groups-c.json').read_text())
b = json.loads((base / 'school-coverage-b.json').read_text())
owners = {row['university']: 'B' for row in b['schoolCoverage'] if row['owner'] == 'B'}
owners.update({school: 'A' for school in a['assignedUniversities']})
owners.update({row['university']: 'C' for row in c['coverage']})
followup_a = ['gachon', 'cau', 'chosun', 'daegu', 'dku', 'donga', 'gnu', 'hansung']
owners.update({school: 'A-followup' for school in followup_a})
applied = {}
for receipt in base.glob('*-integration-receipt.json'):
    data = json.loads(receipt.read_text())
    for school in data.get('schools', []):
        applied.setdefault(school['university'], []).append({'receipt': str(receipt), 'mappingRows': school['mappings'], 'ownerUnits': school['ownerUnits']})
for university, filename, field in [
    ('eulji', 'eulji-integration-receipt.json', 'newMappings'),
    ('iccu', 'iccu-organizations-integration-receipt.json', 'addedMappings'),
]:
    receipt_path = base / filename
    data = json.loads(receipt_path.read_text())
    count = len(data[field]) if isinstance(data[field], list) else data[field]
    applied.setdefault(university, []).append({'receipt': str(receipt_path), 'mappingRows': count, 'ownerUnits': 0})
gachon_receipt = base / 'gachon-cooffering-apply-receipt-a.json'
if gachon_receipt.exists():
    applied.setdefault('gachon', []).append({'receipt': str(gachon_receipt), 'sourceSpecificJointOfferingUnits': 120, 'courses': 88})
catalog = json.loads(Path('assets/timetable/catalog.json').read_text())
datasets = {}
for file in catalog:
    data = json.loads(Path(file).read_text())
    datasets.setdefault(data['universityId'], []).append({'file': file, 'courses': len(data['courses'])})
rows = []
for previous in scope['universities']:
    university = previous['universityId']
    rows.append({
        'universityId': university,
        'name': previous['name'],
        'organizationSourceOwner': owners.get(university, 'root'),
        'wholeCatalogSourceOwner': 'A' if university == 'inje' else 'root',
        'currentDatasets': datasets.get(university, []),
        'organizationAppliedPackets': applied.get(university, []),
        'priorCoverageRemaining': previous.get('previousRemaining'),
        'wholeSupportVerified': False,
        'currentPassCombinedVerification': 'not started; implementation/source scope remains open',
        'sourceLedgerReferences': [str(base / 'school-coverage-b.json'), str(base / 'program-groups-a.json'), str(base / 'program-groups-c.json')],
        'exceptions': ['Timetable disabled by latest user decision; do not reactivate planned source'] if university == 'dju' else [],
    })
ledger = {
    'taskStatus': 'active',
    'completionClaim': False,
    'parallelLimit': {'totalIncludingRoot': 4, 'sourceWorkers': 3},
    'userAuthorization': 'Current university academic/timetable work may use many subagents; do not omit requested scope; explicit resumed scope only',
    'rootResponsibilities': ['Whole-source audit incl JBNU exact clock/native identity', 'Academic calendar coverage audit', 'Evidence-only product integration', 'Shared department major-only filtering and duplicate routes', 'Combined verification after entire implementation scope', 'Canonical Mac test update without app launch'],
    'A': {'completedSourceScope': a['assignedUniversities'], 'followup': followup_a, 'packet': str(base / 'program-groups-root-followup-a-confirmed.json'), 'activeWholeCatalogFollowup': ['inje'], 'sourceDirectory': 'work/full-timetable-audit-20261012/inje-full-a'},
    'B': {'scopeLedger': str(base / 'school-coverage-b.json'), 'appliedPacket': str(base / 'confirmed-program-groups-b.json'), 'activeAffiliationFollowup': ['inje'], 'sourceScopeStillOpen': True},
    'C': {'completedSourceScope': [row['university'] for row in c['coverage']], 'activeClockFollowup': ['inje'], 'sourcePacketDirectory': 'work/full-timetable-audit-20261012/inje-full-a'},
    'installedMacState': 'Previous verified SMU-only correction; current broad pass not built or installed',
    'universities': rows,
}
(base / 'assignment-and-completion-ledger.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n')
print({'requestedLedgerRows': len(rows), 'activeDatasetCount': len(catalog), 'activeUniversities': len(datasets), 'offerings': sum(item['courses'] for group in datasets.values() for item in group), 'completionClaim': False})
