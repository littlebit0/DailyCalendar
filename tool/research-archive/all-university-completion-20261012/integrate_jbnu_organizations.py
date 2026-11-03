"""Connect confirmed official organizations to published native query labels."""
import copy
import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
packet_path = base / 'jbnu-confirmed-affiliation-b.json'
packet = json.loads(packet_path.read_text())
if packet.get('final') is not True:
    raise SystemExit('Unfinished source packet')
path = Path('assets/timetable/organizations/jbnu.json')
data = json.loads(path.read_text())
before = copy.deepcopy(data)
labels = set()
for filename in json.loads(Path('assets/timetable/catalog.json').read_text()):
    dataset = json.loads(Path(filename).read_text())
    if dataset['universityId'] == 'jbnu':
        labels.update(label for course in dataset['courses'] for label in course['departments'])
existing = {(row['campus'], row['sourceLabel'], row['department']): row
            for row in data['mappings']}
added = []
unmatched = []
for entry in packet['entries']:
    if entry['sourceLabel'] not in labels:
        unmatched.append(entry)
        continue
    if not Path(entry['sourceFile']).is_file():
        raise SystemExit('Missing official evidence: ' + entry['sourceFile'])
    key = (entry['campus'], entry['sourceLabel'], entry['department'])
    row = copy.deepcopy(entry)
    row.pop('university')
    kind = row.pop('kind')
    if not row.get('officialGroups'):
        row.pop('officialGroups', None)
    row['isOfferingUnit'] = False
    row['collegeOnlyEligible'] = False
    row['collegeKnown'] = row['college'] is not None
    row['affiliationStatus'] = ('verifiedUniversityDirect' if kind == 'universityDirect'
                                else 'verified' if row['college'] is not None
                                else 'officialProgramSystem')
    if key in existing:
        if existing[key] != row:
            raise SystemExit('Unexpected existing mapping conflict: ' + str(key))
        continue
    data['mappings'].append(row)
    existing[key] = row
    added.append(entry['sourceLabel'])
backup = base / 'jbnu-organizations-before-full-native.json'
if not backup.exists():
    backup.write_text(json.dumps(before, ensure_ascii=False, indent=2) + '\n')
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
receipt = {'packet': str(packet_path), 'schools': [{'university': 'jbnu',
           'mappings': len(added), 'ownerUnits': 0}], 'addedNativeLabels': added,
           'unmatchedEntries': unmatched, 'verificationPending': True,
           'completionClaim': False, 'originalMappingsPreserved': len(before['mappings']),
           'courseOwnersPreserved': before['courseOwners'] == data['courseOwners']}
(base / 'jbnu-organizations-integration-receipt.json').write_text(
    json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print({'addedMappings': len(added), 'unmatched': len(unmatched), 'verificationPending': True})
