"""Immutable physical-campus projection from exact published building abbreviations."""
import copy
import hashlib
import json
from pathlib import Path
from prepare_cuk_published_regular_candidate import ROOT, load

SOURCE = 'catholic-unknown-2026-2.published-regular-1015-candidate-20261008.json'

def prepare():
    original = load(SOURCE)
    proof = load('cuk-current-course-campus-building-crosscheck-20261008.json')
    by_id = {(c['code'], c['section']): c for c in proof['courses']}
    manifest = {'wholeCount': 1459, 'wholeScheduledCount': 1015, 'wholeDatedMeetingCount': 21704,
                'sourceFile': SOURCE, 'sourceSha256': hashlib.sha256((ROOT / SOURCE).read_bytes()).hexdigest(),
                'sourceIdPolicy': 'Retain all original stable sourceIds despite physicalcampus relocation.',
                'completionClaim': False, 'productionRegistered': False, 'datasets': []}
    for campus, label in [('songsim', '성심교정'), ('unknown', '캠퍼스 미표기')]:
        dataset = copy.deepcopy(original)
        dataset.update(campus=campus, campusName=label)
        dataset['courses'] = []
        for old in original['courses']:
            row = by_id[(old['courseCode'], old['section'])]
            physical = row['derivedPhysicalCampus'] or 'unknown'
            if physical != campus:
                continue
            c = copy.deepcopy(old)
            c['campus'] = campus
            c['sourceEducation'].update(sourceCampusExplicit=None, derivedPhysicalCampus=row['derivedPhysicalCampus'],
                derivedPhysicalCampusEvidence={'sourceUrl': 'https://www.catholic.ac.kr/ko/about/campus-map.do?mode=getPlaceListByCondition&campus=1',
                    'proofFile': 'cuk-current-public-campus-building-proof-20261008.json',
                    'sourceSha256': '7971167a23318757442e0506d0ce796679225dfcbfa6384bee49df9e65ef17a7',
                    'exactBuildingPrefixes': row['exactBuildingPrefixes'], 'reason': row['reason']})
            dataset['courses'].append(c)
        name = f'catholic-{campus}-2026-2.published-regular-1015-campus-candidate-20261008.json'
        path = ROOT / name
        assert not path.exists(), 'Immutable output exists'
        path.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n')
        manifest['datasets'].append({'campus': campus, 'file': name,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'courseCount': len(dataset['courses']),
            'scheduledCount': sum(bool(c['schedules']) for c in dataset['courses']),
            'datedMeetingCount': sum(len(c['schedules']) for c in dataset['courses'])})
    out = ROOT / 'cuk-published-regular-1015-campus-split-manifest-20261008.json'
    assert not out.exists()
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(manifest, ensure_ascii=False))

if __name__ == '__main__':
    prepare()
