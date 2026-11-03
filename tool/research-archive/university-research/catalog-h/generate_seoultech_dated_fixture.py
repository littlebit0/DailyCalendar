"""Prepare validated dated public courses for importer review, not activation."""
import json
from pathlib import Path

from normalize_seoultech_future import normalize


def course(offering, document):
    parsed = normalize(document)
    key = offering['SUBJ_CD'] + '-' + offering['LECT_NUMB']
    if key != parsed['sourceCourseKey'] or document['publishedCourseTitle'] != offering['SUBJ_KNM']:
        raise ValueError('Offering and dated schedule disagree')
    if document['publishedDepartment'] != offering['SP_LESS_CD_NM']:
        raise ValueError('Published department mismatch')
    department = offering['SP_LESS_CD_NM']
    meetings = [{k: v for k, v in meeting.items() if k != 'publishedType'}
                for meeting in parsed['meetings']]
    lines = [f"{m['date']} {m['startMinute']//60:02d}:{m['startMinute']%60:02d}"
             f"~{m['endMinute']//60:02d}:{m['endMinute']%60:02d} "
             f"{m['publishedType']} · {m['classroom']}" for m in parsed['meetings']]
    lines.extend(f"{w['startDate']}~{w['endDate']} VOD" for w in parsed['videoAvailability'])
    remarks = [str(offering[k]).strip() for k in ('NOTE', 'ETC') if offering.get(k)]
    for key, label in [('OTSH_LIMT_YN', '타교생제한여부'), ('DLES_COUR_PBT_YN', '타과제한')]:
        value = offering.get(key)
        if value not in ('Y', 'N', None):
            raise ValueError('Unexpected published restriction flag')
        if value is not None:
            remarks.append(f'{label}: {value}')
    credits = float(offering['UNIT'])
    if not 0 <= credits <= 30:
        raise ValueError('Invalid published credits')
    return {
        'sourceId': f"seoultech/main/2026/2/{offering['SUBJ_CD']}/{offering['LECT_NUMB']}",
        'campus': 'main', 'academicYear': 2026, 'semester': '2',
        'courseCode': offering['SUBJ_CD'], 'section': offering['LECT_NUMB'],
        'courseName': offering['SUBJ_KNM'], 'professor': offering.get('PROF_NM') or '',
        'credits': credits, 'schedules': meetings,
        'scheduleStatus': 'scheduled' if meetings else 'unscheduled',
        'sourceSchedule': '\n'.join(lines),
        'sourceClassroom': ' / '.join(dict.fromkeys(m['classroom'] for m in meetings if m['classroom'])),
        'departments': [department], 'departmentCredits': {department: credits},
        'departmentClassifications': {department: offering['CMPT_DIV_NM']},
        'departmentRemarks': {department: '\n'.join(remarks)},
    }


if __name__ == '__main__':
    root = Path(__file__).resolve().parent
    offerings = {r['SUBJ_CD'] + '-' + r['LECT_NUMB']: r for r in
                 json.loads((root / 'seoultech-unique2026-2.json').read_text())}
    courses = []
    for path in sorted((root / 'seoultech-future-public-schedules').glob('*.json')):
        document = json.loads(path.read_text())
        courses.append(course(offerings[document['sourceCourseKey']], document))
    dataset = {'schemaVersion': 2, 'universityId': 'seoultech', 'campus': 'main',
               'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-07',
               'sourceUrl': 'https://for-s.seoultech.ac.kr/html/pub/schedule.jsp',
               'researchOnly': True, 'completionClaim': False, 'wholeUniversity': False,
               'courses': courses}
    (root / 'seoultech-dated-research-dataset.json').write_text(
        json.dumps(dataset, ensure_ascii=False, indent=2))
    print('Prepared public dated research courses:', len(courses))
