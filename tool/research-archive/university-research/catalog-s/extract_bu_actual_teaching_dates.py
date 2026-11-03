"""Read the official corrected weekday teaching-date table without recurrence guesses."""
import datetime
import json
import re
from pathlib import Path
ROOT = Path(__file__).parent


def extract(tables):
    rows = tables[0]['tables'][0]
    if rows[0] != ['주차', '월', '화', '수', '목', '금'] or len(rows) != 16:
        raise ValueError('Changed official teaching-week table shape')
    records = []
    for number, row in enumerate(rows[1:], 1):
        if row[0] != str(number) or len(row) != 6:
            raise ValueError('Invalid actual week sequence')
        for original_day, raw in enumerate(row[1:], 1):
            m = re.fullmatch(r'(\d+)월\s*(\d+)일(?:\([월화수목금토일]\))?(?:\n\((개강일|종강일|원격수업|지정보강일)\))?', raw)
            if not m:
                raise ValueError('Unrecognized actual teaching date')
            month, day, kind = m.groups()
            date = datetime.date(2026, int(month), int(day))
            if not datetime.date(2026, 9, 1) <= date <= datetime.date(2026, 12, 21):
                raise ValueError('Date outside actual semester')
            if date.isoweekday() != original_day and kind != '지정보강일':
                raise ValueError('Undocumented weekday substitution')
            records.append({'week': number, 'sourceWeekday': original_day,
                            'date': date.isoformat(), 'weekday': date.isoweekday(),
                            'kind': kind or '정상수업', 'raw': raw})
    if len(records) != 75 or sum(r['kind'] == '원격수업' for r in records) != 5:
        raise ValueError('Changed official physical/remote scope')
    return {'url': 'https://bhm.bu.ac.kr/bbs/web/788/57347/download.do',
            'corrected': '2026-08-25', 'records': records,
            'remoteEvidence': '2026-2 수업 운영 주요사항: 원격수업(동영상강의), 2026-10-15~2026-10-21'}


if __name__ == '__main__':
    result = extract(json.loads((ROOT/'bu-current-actual-teaching-weeks-20260825.tables.json').read_text()))
    (ROOT/'bu-current-official-teaching-date-records.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print('Actual dates', len(result['records']))
