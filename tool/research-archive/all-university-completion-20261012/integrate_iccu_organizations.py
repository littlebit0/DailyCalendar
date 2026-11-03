import copy
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
source = Path('work/full-timetable-audit-20261012/limited-c-public-sources/iccu-new-organizations-packet.json')
packet = json.loads(source.read_text())
if packet['final'] is not True:
    raise SystemExit('Unfinished source packet')
path = Path('assets/timetable/organizations/iccu.json')
data = json.loads(path.read_text())
backup = base / 'iccu-organizations-before-guide.json'
if not backup.exists():
    backup.write_bytes(path.read_bytes())
labels = {label for row in json.loads(Path('assets/timetable/iccu-songdo-2026-2.json').read_text())['courses'] for label in row['departments']}
existing = {(row['campus'], row['sourceLabel'], row['department']) for row in data['mappings']}
added = []
for entry in packet['entries']:
    key = (entry['campus'], entry['sourceLabel'], entry['department'])
    if key in existing:
        raise SystemExit('New packet unexpectedly overlaps existing organization')
    if entry['sourceLabel'] not in labels:
        raise SystemExit('Official program has no current native course-query relationship')
    row = copy.deepcopy(entry)
    row.pop('university')
    row.pop('kind')
    row['sourceFile'] = packet['sourceFile']
    row['collegeKnown'] = row['college'] is not None
    row['collegeOnlyEligible'] = False
    row['affiliationStatus'] = 'verified' if row['college'] is not None else 'officialProgramSystem'
    data['mappings'].append(row)
    added.append(entry['sourceLabel'])
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
receipt = {'sourcePacket': str(source), 'addedMappings': added, 'existingOwnersPreserved': len(data['courseOwners']), 'verificationPending': True, 'completionClaim': False}
(base / 'iccu-organizations-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print({'addedMappings': len(added), 'verificationPending': True})
