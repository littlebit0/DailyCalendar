"""Validate published dated teaching sessions without inventing VOD clocks.

Research output is not an enabled catalog. Exact delivery modes remain separate
until the app importer can preserve them when users choose a default mode.
"""
import datetime as dt
import json
from pathlib import Path
import re


def normalize(document):
    if document['term'] != '20262':
        raise ValueError('Unexpected published term')
    key = document['sourceCourseKey']
    if not re.fullmatch(r'\d+-\d+', key):
        raise ValueError('Invalid course identity')
    meetings, windows = [], []
    seen = set()
    for row in document['rows']:
        start = dt.datetime.fromisoformat(row['LS_DT'])
        end = dt.datetime.fromisoformat(row['LS_EDT'])
        if start.year != 2026 or end < start:
            raise ValueError('Invalid published dates')
        kind = row['SUBJ_TYPE']
        clock = row['LS_TM_CD_NM'].strip()
        if kind == 'VOD':
            if clock != '-':
                raise ValueError('Unexpected timed VOD')
            windows.append({'startDate': start.date().isoformat(),
                            'endDate': end.date().isoformat(), 'type': kind})
            continue
        if kind not in ('출석수업', '화상강의', '중간고사', '기말고사'):
            raise ValueError('Unknown published teaching type')
        match = re.fullmatch(r'(\d{2}):(\d{2})\s*~\s*(\d{2}):(\d{2})', clock)
        if match is None or start.date() != end.date():
            raise ValueError('Missing single-date clock')
        sh, sm, eh, em = map(int, match.groups())
        if not (0 <= sh < 24 and 0 <= eh <= 24 and 0 <= sm < 60 and
                0 <= em < 60 and (eh < 24 or em == 0)):
            raise ValueError('Invalid clock')
        begin, finish = sh * 60 + sm, eh * 60 + em
        if finish <= begin:
            raise ValueError('Invalid teaching duration')
        # SC rows publish only a date; attendance/exams sometimes include time.
        if ' ' in row['LS_DT'] and start.hour * 60 + start.minute != begin:
            raise ValueError('Published start and clock disagree')
        meeting = {'date': start.date().isoformat(),
                   'weekday': start.isoweekday(), 'startMinute': begin,
                   'endMinute': finish, 'classroom': row['LS_BLDG_COUM_NM'],
                   'publishedType': kind}
        if kind in ('출석수업', '화상강의'):
            meeting['deliveryMode'] = ('inPerson' if kind == '출석수업'
                                       else 'liveOnline')
        identity = tuple(meeting.values())
        if identity not in seen:
            meetings.append(meeting)
            seen.add(identity)
    return {'sourceCourseKey': key, 'meetings': meetings,
            'videoAvailability': windows}


if __name__ == '__main__':
    root = Path(__file__).resolve().parent
    normalized = [normalize(json.loads(path.read_text())) for path in
                  sorted((root / 'seoultech-future-public-schedules').glob('*.json'))]
    result = {'researchOnly': True, 'completionClaim': False,
              'courses': normalized}
    (root / 'seoultech-future-normalized.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2))
    print('Validated published course-specific dates:', len(normalized))
