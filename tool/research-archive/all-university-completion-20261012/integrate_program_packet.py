"""Apply exact source-evidenced affiliations; preserve all course source assets."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('packet')
args = parser.parse_args()
packet_path = Path(args.packet)
packet = json.loads(packet_path.read_text())
if packet.get('final') is not True:
    raise SystemExit('Source packet remains open; do not apply it wholesale')
base = packet_path.parent
receipt = {'packet': str(packet_path), 'packetSha256': hashlib.sha256(packet_path.read_bytes()).hexdigest(), 'verificationPending': True, 'completionClaim': False, 'schools': [], 'unmatchedEntries': []}
fields = ('college', 'department', 'group', 'officialGroups', 'officialSystem', 'officialSystems', 'officialAcademicParent', 'sourceUrl', 'sourceFile', 'evidence', 'additionalSourceUrls')
universities = {row['university'] for row in packet['entries']}
campus_by_school = {school: {} for school in universities}
labels_by_school = {school: {} for school in universities}
# Read each large source asset once, retaining only the exact identity index.
for source in json.loads(Path('assets/timetable/catalog.json').read_text()):
    dataset = json.loads(Path(source).read_text())
    university = dataset['universityId']
    if university not in universities:
        continue
    for course in dataset['courses']:
        campus = course.get('campus', dataset['campus'])
        campus_by_school[university][course['sourceId']] = campus
        for label in course['departments']:
            labels_by_school[university].setdefault(label, set()).add(campus)
for university in sorted(universities):
    path = Path(f'assets/timetable/organizations/{university}.json')
    data = json.loads(path.read_text())
    before = copy.deepcopy(data)
    entries = [row for row in packet['entries'] if row['university'] == university]
    campus_by_course = campus_by_school[university]
    campuses_by_label = labels_by_school[university]
    matched = set()
    counts = {'mappings': 0, 'ownerUnits': 0}
    sections = [
        ('mappings', [(unit, None) for unit in data['mappings']]),
        ('ownerUnits', [(unit, campus_by_course.get(owner['sourceId']))
                        for owner in data['courseOwners'] for unit in owner['units']]),
    ]
    for section, units in sections:
        for unit, owner_campus in units:
            def campus_matches(row):
                if row['campus'] == '*':
                    return True
                actual_campus = owner_campus or unit.get('campus')
                if actual_campus not in (None, '*'):
                    return row['campus'] == actual_campus
                # A wildcard legacy mapping can be safely narrowed only when
                # this exact published label occurs in one actual campus.
                return campuses_by_label.get(unit.get('sourceLabel')) == {row['campus']}
            # Never infer a course affiliation from a same-title program alone.
            matches = [(i, row) for i, row in enumerate(entries) if row['sourceLabel'] == unit.get('sourceLabel') and row['department'] == unit.get('department') and campus_matches(row)]
            if not matches:
                continue
            identities = {(r.get('college'), r.get('group'), tuple(r.get('officialGroups', []))) for _, r in matches}
            if len(identities) != 1:
                raise SystemExit(f'Ambiguous source mapping: {university} {unit}')
            _, row = matches[0]
            if section == 'mappings' and unit.get('campus') == '*' and row['campus'] != '*':
                unit['campus'] = row['campus']
            matched.update(i for i, _ in matches)
            # Clear superseded program headings but retain eligibility/owner identity.
            for field in fields:
                if field in row:
                    unit[field] = copy.deepcopy(row[field])
                elif field in ('group', 'officialGroups', 'officialSystem', 'officialSystems'):
                    unit.pop(field, None)
            if not unit.get('officialGroups'):
                unit.pop('officialGroups', None)
            unit['collegeKnown'] = unit.get('college') is not None
            default_status = {
                'universityDirect': 'verifiedUniversityDirect',
                'officialProgramSystem': 'officialProgramSystem',
            }.get(row['kind'], 'verified')
            unit['affiliationStatus'] = row.get('affiliationStatus', default_status)
            counts[section] += 1
    backup = base / f'{university}-before-{packet_path.stem}.json'
    if not backup.exists():
        backup.write_text(json.dumps(before, ensure_ascii=False, indent=2) + '\n')
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    receipt['schools'].append({'university': university, **counts, 'sourceEntries': len(entries), 'unchangedCourseOwnersCount': len(data['courseOwners'])})
    receipt['unmatchedEntries'].extend(entries[i] for i in range(len(entries)) if i not in matched)
(base / f'{packet_path.stem}-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'schools': len(receipt['schools']), 'mappingRows': sum(r['mappings'] for r in receipt['schools']), 'ownerUnits': sum(r['ownerUnits'] for r in receipt['schools']), 'unmatched': len(receipt['unmatchedEntries']), 'verificationPending': True}))
