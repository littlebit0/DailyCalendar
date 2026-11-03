# coding: utf-8
"""Preserve source metadata separately while making partial-scope notes visible."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).parent
BASE = 'bu-current-whole-ordinary-partial-next-20261008.json'
NEXT = 'bu-current-whole-ordinary-app-notes-next-20261008.json'
FIELDS = ['sourceId', 'courseCode', 'section', 'courseName', 'credits', 'professor',
          'departments', 'departmentCredits', 'departmentClassifications',
          'departmentRemarks', 'classification', 'sourceSchedule', 'sourceClassroom',
          'campus']


def sha(name):
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def prepare():
    base = json.loads((ROOT / BASE).read_text())
    result = copy.deepcopy(base)
    for row, source in zip(result['courses'], base['courses']):
        row['sourceEducationalMetadata'] = {key: copy.deepcopy(source[key]) for key in FIELDS}
        original_text = ' / '.join(dict.fromkeys(source['departmentRemarks'].values()))
        annotation = source['remarks']
        while original_text and annotation.startswith(original_text):
            annotation = annotation[len(original_text):].removeprefix(' / ')
        row['departmentRemarks'] = {
            department: ' / '.join(value for value in [
                source['departmentRemarks'].get(department, ''), annotation] if value)
            for department in source['departments']}
        for department, original in source['departmentRemarks'].items():
            assert department in row['departmentRemarks']
            assert row['departmentRemarks'][department].startswith(original)
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    target = ROOT / NEXT
    if target.exists():
        assert target.read_text() == encoded, 'Immutable candidate bytes cannot change'
    else:
        target.write_text(encoded)
    audit = json.loads((ROOT / 'bu-current-whole-ordinary-partial-next-audit-20261008.json').read_text())
    audit.update({'candidate': NEXT, 'candidateSHA256': sha(NEXT),
                  'previousCandidate': BASE, 'previousCandidateSHA256': sha(BASE),
                  'originalSourceMetadataPreservedIn': 'sourceEducationalMetadata',
                  'displayedDepartmentRemarksAnnotation': True,
                  'originalDepartmentRemarksPrefixMismatchCount': 0,
                  'sourceMetadataMismatchCount': 0})
    (ROOT / 'bu-current-whole-ordinary-app-notes-next-audit-20261008.json').write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'candidate': NEXT, 'sha256': sha(NEXT), 'counts': result['counts'],
                      'datedMeetings': audit['datedMeetingCount']}))


if __name__ == '__main__':
    prepare()
