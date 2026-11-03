"""Eight individually reviewed dated plans; unrelated offerings remain identical."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from sogang_public_education import same_educational_value

ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-v5-20261008'
BASE = ROOT / 'sogang-additions-v4-20261008/sogang-unknown-2026-2.fifty-eight-reviewed-20261008.json'
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
proofs = []
config = [
    ('AMC4130-01', 27, '계획서의 실제 일반 수업 26회와 공시·계획서가 일치하는 10/26 중간시험만 반영합니다. 10/5 휴일, 10/21·12/16 No Class, 12/14 에세이 제출과 시각 미확정 12/21 기말시험은 출석으로 생성하지 않습니다. 영어로 모든 자료·강의·발표·에세이를 진행하며 무단 결석 5회이면 F, 15분 초과 지각은 결석 처리합니다. 2~4학년 대상, 계획서 교실 TBA와 현재 공시 J327을 구분합니다.'),
    ('AMC2033-01', 27, '계획서의 실제 일반 수업 26회와 공시·계획서가 일치하는 10/21 중간시험만 반영합니다. 10/5 휴일, 10/26 No Class, 12/14 에세이 제출과 시각 미확정 12/16 기말시험은 출석으로 생성하지 않습니다. 영어로 모든 자료·강의·발표·에세이를 진행하며 무단 결석 5회이면 F, 15분 초과 지각은 결석 처리합니다. 계획서 교실 TBA와 현재 공시 J107을 구분합니다.'),
    ('HFS2001-01', 25, '현재 계획서가 명시한 정규 대면 운영을 보존합니다. 9/18 축제 운영 미확인, 9/25·10/9 휴일, 11/20 학교 스터디데이 휴강은 보류/제외합니다. 직접 날짜의 일반 대면 수업 24회와 공시·계획서 일치 10/21 대면 중간시험만 반영합니다. 12/16 기말 실제 시각은 미확인 보류. 휴강 보강·입시로 강의실 사용 불가 시 Zoom 또는 학생 자체 비대면 토론 등으로 바뀔 수 있으며 날짜별 변경 확정은 후속 공지 확인이 필요합니다. 계획서 강의실 추후 공지와 현재 공시 K504를 구분합니다.'),
    ('HFU4023-01', 25, '현재 계획서가 명시한 정규 대면 운영을 보존합니다. 교실에서 동영상 강의 자료와 조별 토론을 병행하는 계획을 영상강의 수강 모드로 바꾸지 않습니다. 9/18 축제 운영 미확인, 9/25·10/9 휴일, 11/20 학교 스터디데이 휴강 보류/제외. 일반 대면 계획 24회와 공시·계획서 일치 10/21 대면 중간시험만 반영합니다. 12/16 기말 실제 시각 미확인 보류. 강의실 사용 불가 시 Zoom·비대면 토론으로 바뀔 수 있어 후속 공지 확인이 필요합니다. 계획서 강의실 추후 공지와 현재 MA308을 구분합니다.'),
    ('HIS3051-01', 28, '정규 계획 27회와 공시·계획서 일치 10/20 중간시험을 반영합니다. 9/24 공휴일과 실제 시각 미확정 12/15 기말시험은 생성하지 않습니다. 공개 개별 계획서 구분은 전공선택(3학점)으로 원문을 보존합니다. 수강대상 전학년·2~4학년 권장, 유고결석 및 지원·일정 조율 조건을 구분합니다.'),
    ('HIS3040-01', 23, '1주 계획서 9/2·9/4는 공시 화·목과 다른 수·금이므로 보류하고 9/1·9/3으로 고치지 않습니다. 9/10 개강미사, 9/24 추석, 11/5 사학과 답사 휴강을 제외합니다. 12/3 대한민국역사박물관 현장학습은 실제 집합 시각·장소 상세 미확인으로 교실 출석을 생성하지 않습니다. 일반 계획 22회와 계획서 10/20 또는 10/22 중 현재 공시로 배정된 10/22 중간시험만 반영합니다. 12/15 또는 12/17 기말 실제 배정·시각 미확인 보류.'),
    ('MAS3001-01', 25, '3주차 3/15·3/17은 학기 밖 날짜로 보류하고 9월로 수정하지 않습니다. 정규 강의·교실 활동 24회와 공시·계획서 일치 10/22 중간시험만 반영합니다. 9/10은 같은 시각의 개강미사로 계획서에 안내되어 일반 강의 배정 미확인 보류, 9/24 휴일 제외. 10/20 중간 주간의 나머지 슬롯과 기말 12/15·17 실제 시험 배정·시각 미확인 보류. 각 수업 진도에 따라 계획 변경 가능 및 지각 제출·시험 조건 확인.'),
    ('MAE4001-01', 26, '계획서의 정규 일반 수업 26회만 반영합니다. 계획서가 9/22·9/24 두 날짜를 추석 No Class로 명시해 둘 다 제외합니다(9/22를 전국 공휴일이라고 해석하지 않습니다). 8주 Midterm No Class와 16주 기말 실제 출석·평가 시각 미확인으로 시험 예약을 생성하지 않습니다. 각 수업 진도와 후속 공지에 따라 바뀔 수 있습니다.'),
]
for key, expected, note in config:
    source = json.loads((OUT / f'{key}.source-education.json').read_text())
    row = source['currentPublicRow']
    text = source['weeklyOperatingText']
    c = next(c for c in result['courses'] if c['courseCode'] + '-' + c['section'] == key)
    assert not c['schedules']
    assert source['currentBytesEqualPrior']
    assert c['courseCode'] in source['sourceHeader']
    assert all(same_educational_value(k, row.get(k, ''), v) for k, v in c['sourceEducationalMetadata'].items())
    clock = re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})', row['meetingText'])
    start = int(clock[1]) * 60 + int(clock[2])
    end = int(clock[3]) * 60 + int(clock[4])
    assert end - start == 75
    room = re.search(r'\[([^\]]+)\]', row['meetingText'])[1]
    weekdays = {1, 3} if key.startswith('AMC') else {3, 5} if key.startswith(('HFS', 'HFU')) else {2, 4}
    meetings, holds, evidence = [], [], []
    if key.startswith('AMC'):
        entries = list(re.finditer(r'(?<!\d)(\d{1,2})/(\d{1,2})\s+(Topic|Assignment)', text))
        for i, m in enumerate(entries):
            date = dt.date(2026, int(m[1]), int(m[2]))
            body = text[m.end():entries[i + 1].start() if i + 1 < len(entries) else len(text)]
            assert date.isoweekday() in weekdays
            if m[3] == 'Assignment' or any(v in body for v in ['Holiday', 'No Class', 'Midterm Exam', 'Final Exam']):
                holds.append({'date': date.isoformat(), 'sourceOperatingBody': body, 'reason': 'assignment/no class/holiday or assessment allocation'})
                continue
            meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': start, 'endMinute': end, 'classroom': room})
            evidence.append({'printedDates': [date.isoformat()], 'sourceOperatingBody': body})
    elif key.startswith(('HFS', 'HFU')):
        assert '대면' in source['publishedOperatingExcerpt']
        entries = list(re.finditer(r'(?<!\d)(\d{1,2})/(\d{1,2})\s*[수금]', text))
        for i, m in enumerate(entries):
            date = dt.date(2026, int(m[1]), int(m[2]))
            body = text[m.end():entries[i + 1].start() if i + 1 < len(entries) else len(text)]
            assert date.isoweekday() in weekdays
            if date.isoformat() in {'2026-09-18', '2026-09-25', '2026-10-09', '2026-11-20'} or date == dt.date(2026, 10, 21) or date >= dt.date(2026, 12, 15):
                holds.append({'date': date.isoformat(), 'sourceOperatingBody': body, 'reason': 'holiday/festival unconfirmed or assessment allocation'})
                continue
            meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': start, 'endMinute': end, 'classroom': room, 'deliveryMode': 'inPerson'})
            evidence.append({'printedDates': [date.isoformat()], 'sourceOperatingBody': body})
    else:
        blocks = re.split(r'Week\s+(\d+)' if key.startswith(('MAS', 'MAE')) else r'(\d+)(?:~\d+)?\s*주차', text)
        for i in range(1, len(blocks), 2):
            week = int(blocks[i])
            body = blocks[i + 1]
            dates = re.findall(r'(\d{1,2})/(\d{1,2})', body)[:2]
            if key == 'HIS3051-01' and week in (8, 16):
                assert len(dates) == 1
            else:
                assert len(dates) == 2, (key, week, dates)
            for month, day in dates:
                date = dt.date(2026, int(month), int(day))
                if week in (8, 16) or date.isoformat() in {'2026-09-24'} or (key == 'HIS3040-01' and date.isoformat() in {'2026-09-10', '2026-11-05', '2026-12-03'}) or (key == 'MAS3001-01' and date.isoformat() == '2026-09-10') or (key == 'MAE4001-01' and date.isoformat() == '2026-09-22'):
                    holds.append({'date': date.isoformat(), 'week': week, 'reason': 'source no class/holiday/field study or assessment allocation'})
                    continue
                if not dt.date(2026,9,1) <= date <= dt.date(2026,12,21):
                    assert key=='MAS3001-01' and week==3 and date.isoformat() in {'2026-03-15','2026-03-17'}
                    holds.append({'date':date.isoformat(),'week':week,'reason':'source spring month outside actual term; no month correction'})
                    continue
                if date.isoweekday() not in weekdays:
                    assert key == 'HIS3040-01' and week == 1 and date.isoformat() in {'2026-09-02', '2026-09-04'}, (key,week,date,body[:250])
                    holds.append({'date': date.isoformat(), 'week': week, 'reason': 'source weekday conflicts native clock; no correction'})
                    continue
                meetings.append({'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': start, 'endMinute': end, 'classroom': room})
            evidence.append({'week': week, 'printedDates': [dt.date(2026, int(m), int(d)).isoformat() for m, d in dates], 'sourceOperatingBody': body})
    if key != 'MAE4001-01':
        exam = re.search(r'(\d{2})\.(\d{2})\(', row['exam'])
        date = dt.date(2026, int(exam[1]), int(exam[2]))
        assert any(h['date'] == date.isoformat() for h in holds)
        holds = [h for h in holds if h['date'] != date.isoformat()]
        meeting = {'date': date.isoformat(), 'weekday': date.isoweekday(), 'startMinute': start, 'endMinute': end, 'classroom': room}
        if key.startswith(('HFS', 'HFU')):
            meeting['deliveryMode'] = 'inPerson'
        meetings.append(meeting)
    if key == 'HIS3051-01':
        assert '전공선택(3학점)' in re.sub(r'\s+', '', source['sourceHeader'])
        c['sourceNativeClassification'] = '전공선택'
    assert len(meetings) == expected, (key, len(meetings), expected)
    meetings.sort(key=lambda m: m['date'])
    c.update(schedules=meetings, scheduleStatus='scheduled', partialSchedule=True, period={'startDate':meetings[0]['date'], 'endDate':meetings[-1]['date']}, scheduleEvidence={'basis':'currentPublicPlanPrintedDates', 'count':len(meetings), 'attendanceConfirmed':False})
    for dep in c['departmentRemarks']:
        c['departmentRemarks'][dep] += '\n' + note
    proofs.append({'offering':key, 'sourcePdfSHA256':source['fileSha256'], 'sourceWeeks':evidence, 'holds':holds, 'meetings':meetings, 'addedPlans':len(meetings), 'nativeClock':row['meetingText']})
changed = [a['courseCode'] + '-' + a['section'] for a,b in zip(base['courses'],result['courses']) if a != b]
assert len(changed) == 8
assert sum(bool(c['schedules']) for c in result['courses']) == 66
assert sum(len(c['schedules']) for c in result['courses']) == 1592
candidate = OUT / 'sogang-unknown-2026-2.sixty-six-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit = {'baseFile':str(BASE), 'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(), 'candidateFile':candidate.name, 'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(), 'whole':1541, 'previousScheduled':58, 'previousPlans':1386, 'addedScheduled':8, 'addedPlans':206, 'scheduled':66, 'plans':1592, 'changedOnly':changed, 'proofs':proofs, 'otherOfferingsAndSourceIdsUnchanged':True, 'productionEdited':False, 'completionClaim':False, 'deferredReview':[{'offering':'LCU4004-02/03', 'reason':'Fall2026 header but April-June weekly dates; no semester date correction'}, {'offering':'MAS2007-01', 'reason':'regular Mon/Wed header vs multiple Thursday printed dates; no date correction'}]}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('66/1592;8new206 source plans')
