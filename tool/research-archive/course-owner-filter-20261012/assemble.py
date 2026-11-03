"""Package independently retained official organization evidence without editing courses."""
import collections
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORK = pathlib.Path(__file__).resolve().parent
ASSETS = ROOT / 'assets/timetable'
files = json.loads((ASSETS / 'catalog.json').read_text())
courses = {}
campuses = collections.defaultdict(set)
labels = collections.defaultdict(set)
source_hashes = {}
for filename in files:
    path = ROOT / filename
    source_hashes[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    data = json.loads(path.read_text())
    school = data.get('universityId', 'smu')
    courses.setdefault(school, {})
    campuses[school].add(data['campus'])
    for row in data['courses']:
        courses[school][row['sourceId']] = row
        labels[school].update((data['campus'], label) for label in row['departments'])

baseline = json.loads((WORK / 'original-course-hashes.json').read_text())
if source_hashes != baseline:
    raise ValueError('Original course data changed during organization overlay work')

packets = [json.loads((WORK / f'agent-{part}-organizations.json').read_text()) for part in 'abc']
mappings = collections.defaultdict(dict)
owners = collections.defaultdict(lambda: collections.defaultdict(dict))
issues = []

def unit(raw):
    clean = {key: raw.get(key) for key in ['college', 'department', 'sourceLabel', 'sourceUrl', 'evidence']}
    for key in ['college', 'department']:
        if clean[key] is not None and not clean[key].strip():
            clean[key] = None
    if not clean['college'] and not clean['department']:
        raise ValueError(f'No published organization: {raw}')
    if not clean['sourceUrl'] or not clean['evidence']:
        raise ValueError(f'No official evidence: {raw}')
    for key in ['sourceFile', 'isOfferingUnit', 'campus', 'collegeKnown', 'collegeOnlyEligible']:
        if key in raw:
            clean[key] = raw[key]
    return clean

for packet in packets:
    for raw in packet['mappings']:
        school = raw['university']
        if not raw.get('college') and not raw.get('department'):
            issues.append({'type': 'noPublishedOrganization', 'row': raw})
            continue
        clean = unit(raw)
        if clean['department'] in {'전체학과', '전학과', '모든학과', '학과전체', '전체전공'}:
            issues.append({'type': 'notSpecificDepartment', 'row': raw})
            continue
        clean.setdefault('campus', '*')
        if school not in courses or clean['campus'] not in campuses[school] | {'*'}:
            issues.append({'type': 'unmatchedCampus', 'row': raw})
            continue
        if clean['college'] in {'대학(전체)', '전체', '대학 전체'} and clean['department']:
            clean['college'] = None
        if clean['college'] in {'대학(전체)', '전체', '대학 전체'}:
            issues.append({'type': 'notCollege', 'row': raw})
            continue
        key = (clean['campus'], clean['sourceLabel'], clean['college'], clean['department'])
        existing = mappings[school].get(key)
        if existing and existing.get('isOfferingUnit') is True:
            continue
        mappings[school][key] = clean
    for is_association, raw in [(False, r) for r in packet['courseOwners']] + [(True, r) for r in packet.get('courseAssociations', [])]:
        identity = raw['sourceId']
        school = raw.get('university', identity.split('/')[0])
        if school not in courses or identity not in courses[school]:
            issues.append({'type': 'unmatchedCourse', 'university': school, 'sourceId': identity})
            continue
        if not raw.get('college') and not raw.get('department'):
            issues.append({'type': 'noPublishedOrganization', 'row': raw})
            continue
        clean = unit(raw)
        clean['isOfferingUnit'] = not is_association
        if is_association:
            clean['isOfferingUnit'] = False
            if not clean['department']:
                issues.append({'type': 'collegeQueryIsNotHost', 'row': raw})
                continue
        if clean['college'] in {'대학(전체)', '전체', '대학 전체'} and clean['department']:
            clean['college'] = None
        if clean['college'] in {'대학(전체)', '전체', '대학 전체'}:
            issues.append({'type': 'notCollegeOwner', 'university': school, 'sourceId': identity})
            continue
        key = (clean['college'], clean['department'])
        existing = owners[school][identity].get(key)
        if existing and existing.get('isOfferingUnit') and is_association:
            continue
        owners[school][identity][key] = clean

out = ASSETS / 'organizations'
out.mkdir(exist_ok=True)
report = {'sourceHashes': source_hashes, 'schools': [], 'issues': issues,
          'sourceGaps': [gap for packet in packets for gap in packet.get('gaps', [])]}
for school in sorted(courses):
    school_mappings = sorted(mappings[school].values(), key=lambda row: (row['campus'], row['sourceLabel'], row['college'] or '', row['department'] or ''))
    school_owners = [{'sourceId': identity, 'units': list(units.values())} for identity, units in sorted(owners[school].items())]
    data = {'schemaVersion': 1, 'university': school, 'mappings': school_mappings, 'courseOwners': school_owners}
    (out / f'{school}.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    mapped_labels = {(campus, mapping['sourceLabel']) for mapping in school_mappings for campus in campuses[school] if mapping['campus'] in {campus, '*'}}
    unmatched = sorted(labels[school] - mapped_labels)
    report['schools'].append({'university': school, 'courses': len(courses[school]), 'mappings': len(school_mappings), 'courseUnits': len(school_owners), 'actualOwners': sum(any(unit.get('isOfferingUnit') for unit in owner['units']) for owner in school_owners), 'queryAssociatedCourses': sum(any(unit.get('isOfferingUnit') is False for unit in owner['units']) for owner in school_owners), 'unmappedLabels': unmatched})
(WORK / 'assembly-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'schools': len(courses), 'mappings': sum(len(v) for v in mappings.values()), 'owners': sum(len(v) for v in owners.values()), 'issues': len(issues), 'emptySchools': [s for s in courses if not mappings[s] and not owners[s]]}, ensure_ascii=False))
