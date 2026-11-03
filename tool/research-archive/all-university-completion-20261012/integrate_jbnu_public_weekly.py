"""Retain original medical records while adding source-proven public offerings."""
import copy
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
receipt = json.loads((base / 'jbnu-weekly-candidate-receipt.json').read_text())
if receipt['candidateOfferings'] != 3538 or receipt['existingMedicalDocumentPreserved'] != 33:
    raise SystemExit('Unexpected reconciliation scope')
medical_path = Path('assets/timetable/jbnu-unknown-2026-2.json')
medical = json.loads(medical_path.read_text())
if len(medical['courses']) != 33:
    raise SystemExit('Original medical preservation requires review')
backup = base / 'jbnu-original-medical-before-public-expansion.json'
if not backup.exists():
    backup.write_bytes(medical_path.read_bytes())
catalog_path = Path('assets/timetable/catalog.json')
catalog = json.loads(catalog_path.read_text())
new_counts = {}
for source_path in sorted((base / 'jbnu-weekly-candidates').glob('*.json')):
    candidate = json.loads(source_path.read_text())
    candidate['researchOnly'] = False
    candidate['productionIntegrationEnabled'] = True
    campus = candidate['campus']
    path = Path(f'assets/timetable/jbnu-{campus}-2026-2.json')
    if campus == 'unknown':
        combined = copy.deepcopy(medical)
        if {r['sourceId'] for r in medical['courses']} & {r['sourceId'] for r in candidate['courses']}:
            raise SystemExit('Duplicate original/native identity')
        combined['courses'].extend(candidate['courses'])
        combined['sourceRowCount'] = len(combined['courses'])
        combined['additionalSourceUrls'] = [candidate['sourceUrl'], candidate['clockEvidence']['url'], candidate['periodEvidence']['url']]
        combined['supplementarySource'] = {k: copy.deepcopy(candidate[k]) for k in ['sourceUrl', 'publishedDate', 'clockEvidence', 'periodEvidence', 'coverage']}
        combined['coverage'] = 'Original33 medical document records unchanged plus233 native offerings whose campus is unpublished. Native medical duplicates held for source identity reconciliation; no inferred campus.'
        result = combined
    else:
        if path.exists():
            raise SystemExit('Unexpected prior campus asset')
        result = candidate
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    if str(path) not in catalog:
        catalog.append(str(path))
    new_counts[campus] = len(candidate['courses'])
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
receipt['productApplied'] = True
receipt['newNativeCourseCountsByCampus'] = new_counts
receipt['currentOfferingsIncludingOriginalMedical'] = 3571
receipt['verificationPending'] = True
(base / 'jbnu-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print({'additionalNativeOfferings': sum(new_counts.values()), 'campusCounts': new_counts, 'originalMedicalPreserved': 33, 'verificationPending': True, 'wholeCompletion': False})
