"""서강대 2026-2 시간표 자산을 2026-10-23 공식 조회와 공개 강의계획서 기준으로 갱신한다.

사용: python3 -I update_asset.py <asset.json> <work-dir>
- 공식 개설교과목 조회(오늘 수집본)와 원자료 필드를 맞춘다(시험일자·교수·학과·강의실).
- 공개 강의계획서가 대면 운영과 수업 시각을 직접 적은 23강좌만 정규 주간 예약을 넣는다.
"""
import copy, datetime, hashlib, json, re, sys
from pathlib import Path

asset_path = Path(sys.argv[1]); work = Path(sys.argv[2])
current_file = work / 'data/sogang-current-20261023.json'
CURRENT_REL = 'work/issue-604-sogang-timetable/data/sogang-current-20261023.json'
current_sha = hashlib.sha256(current_file.read_bytes()).hexdigest()
cur = {r['subjectCode'] + '-' + r['section']: r for r in json.loads(current_file.read_text())['records']}
texts = json.loads((work / 'data/plans-20261023/texts.json').read_text())
plan_log = json.loads((work / 'data/plans-20261023/fetch-log.json').read_text())['entries']
data = json.loads(asset_path.read_text())
courses = {c['courseCode'] + '-' + c['section']: c for c in data['courses']}
assert set(courses) == set(cur), 'official scope differs'

EXAM = re.compile(r'(\d{1,2})\.(\d{1,2})\((.)\)(\d{2}):(\d{2})~(\d{2}):(\d{2})\[([^\]]*)\]')
MEET = re.compile(r'(?P<days>[월화수목금토일](?:,[월화수목금토일])*) (?P<s>\d{2}:\d{2})~(?P<e>\d{2}:\d{2}) \[(?P<room>[^\[\]]+)\]')
WD = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7}
START, END = datetime.date(2026, 9, 1), datetime.date(2026, 12, 21)
FIXED = ({datetime.date(2026, 9, d) for d in (18, 24, 25, 26)} | {datetime.date(2026, 10, d) for d in (3, 5, 9)}
         | {datetime.date(2026, 11, 20)} | {datetime.date(2026, 10, d) for d in range(20, 27)}
         | {datetime.date(2026, 12, d) for d in range(15, 22)})
norm_rooms = lambda v: re.sub(r'\[([^\]]+)\]', lambda m: '[' + ','.join(sorted(m[1].split(','))) + ']', v)
mins = lambda hh, mm: int(hh) * 60 + int(mm)


def clock_text(text):
    return CLOCK.search(text[:1500]).group(0)


def parse_exam(text):
    m = EXAM.fullmatch(text)
    assert m, text
    d = datetime.date(2026, int(m[1]), int(m[2]))
    assert d.isoweekday() == WD[m[3]], text
    return {'date': d, 'start': mins(m[4], m[5]), 'end': mins(m[6], m[7]), 'room': m[8], 'clock': f'{m[4]}:{m[5]}–{m[6]}:{m[7]}'}


def exam_dates(text):
    return {datetime.date(2026, int(a), int(b)) for a, b in re.findall(r'(\d{1,2})\.(\d{1,2})\(', text)}


def weekly(meeting, exam_text, extra=()):
    m = MEET.fullmatch(meeting); assert m, meeting
    days = {WD[x] for x in m['days'].split(',')}
    sm, em = mins(*m['s'].split(':')), mins(*m['e'].split(':'))
    skip = FIXED | exam_dates(exam_text) | set(extra)
    out = []
    for i in range((END - START).days + 1):
        d = START + datetime.timedelta(days=i)
        if d.isoweekday() in days and d not in skip:
            out.append({'weekday': d.isoweekday(), 'startMinute': sm, 'endMinute': em, 'classroom': m['room'], 'date': d.isoformat()})
    return out


def hidden_sentence(e):
    room = e['room'] or '미게시'
    return f"공식 현재2026-2 공개 시험 약속만 제공: {e['date'].isoformat()} {e['clock']}, 장소 {room}."


HIDDEN = re.compile(r'공식 현재2026-2 공개 시험 약속만 제공: .*?\.(?=\s|$)')


def hidden_match(text):
    found = list(HIDDEN.finditer(text))
    assert len(found) == 1, text
    return found[0]


def replace_exam_line(c, old, new):
    for dep, text in c['departmentRemarks'].items():
        line = '공개시험일자: ' + old
        if old:
            assert line in text.split('\n'), (c['sourceId'], dep)
            lines = text.split('\n')
            idx = lines.index(line)
            if new:
                lines[idx] = '공개시험일자: ' + new
            else:
                del lines[idx]
            c['departmentRemarks'][dep] = '\n'.join(lines)
        elif new:
            raise AssertionError('new exam without old line: ' + c['sourceId'])


report = {'metadataChanged': [], 'examChanged': [], 'hiddenExamCleared': [], 'resolved': [], 'scheduleEdits': []}

# 1) 공식 조회 필드 동기화
for k, c in courses.items():
    old, new = c['sourceEducationalMetadata'], cur[k]
    assert set(old) == set(new), k
    diff = [f for f in old if old[f] != new[f]]
    if not diff:
        continue
    report['metadataChanged'].append({'offering': k, 'fields': {f: [old[f], new[f]] for f in diff}})
    if 'professor' in diff:
        assert c['professor'] == old['professor'], k
        c['professor'] = new['professor']
    if 'department' in diff:
        o, n = old['department'], new['department']
        assert c['departments'] == [o], k
        c['departments'] = [n]
        for field in ('departmentCredits', 'departmentClassifications', 'departmentRemarks'):
            c[field] = {(n if key == o else key): v for key, v in c[field].items()}
    if 'meetingText' in diff:
        om, nm = MEET.fullmatch(old['meetingText']), MEET.fullmatch(new['meetingText'])
        assert om and nm and (om['days'], om['s'], om['e']) == (nm['days'], nm['s'], nm['e']), k
        assert c['sourceSchedule'] == old['meetingText'], k
        c['sourceSchedule'] = new['meetingText']
        for s in c['schedules']:
            assert s['classroom'] == om['room'], k
            s['classroom'] = nm['room']
        if 'reservationEvidence' in c:
            c['reservationEvidence']['sourceMeetingText'] = new['meetingText']
        report['scheduleEdits'].append({'offering': k, 'change': f"강의실 {om['room']} -> {nm['room']} ({len(c['schedules'])}회)"})
    if 'exam' in diff and norm_rooms(old['exam']) != norm_rooms(new['exam']):
        report['examChanged'].append({'offering': k, 'before': old['exam'], 'after': new['exam']})
    if 'exam' in diff:
        replace_exam_line(c, old['exam'], new['exam'])
    c['sourceEducationalMetadata'] = copy.deepcopy(new)
    if 'exam' not in diff:
        continue
    # 정규 주간 예약: 바뀐 시험일로 다시 만든 결과가 지금 예약과 같아야 한다(시험 주간 안의 변경만 있음).
    if 'reservationEvidence' in c:
        regenerated = weekly(c['sourceSchedule'], new['exam'])
        assert regenerated == c['schedules'], ('reservation dates would change', k)
        c['reservationEvidence']['excludedNativeExamDates'] = sorted(d.isoformat() for d in exam_dates(new['exam']))
    ev = c.get('publishedExamAppointmentEvidence')
    if ev is not None:
        assert len(c['schedules']) == 1, k
        before = parse_exam(old['exam'])
        if not new['exam']:
            # 공식 조회가 시험일자를 더 이상 게시하지 않아 남은 시각 근거가 없다.
            for dep, text in c['departmentRemarks'].items():
                c['departmentRemarks'][dep] = text[:hidden_match(text).start()].rstrip('\n')
            del c['publishedExamAppointmentEvidence']
            del c['period']
            c['schedules'] = []
            c['scheduleStatus'] = 'unrecognized'
            report['hiddenExamCleared'].append({'offering': k, 'before': old['exam']})
            continue
        after = parse_exam(new['exam'])
        for dep, text in c['departmentRemarks'].items():
            m = hidden_match(text)
            c['departmentRemarks'][dep] = text[:m.start()] + hidden_sentence(after) + text[m.end():]
        c['schedules'] = [{'weekday': after['date'].isoweekday(), 'startMinute': after['start'], 'endMinute': after['end'],
                           'classroom': after['room'], 'date': after['date'].isoformat()}]
        c['period'] = {'startDate': after['date'].isoformat(), 'endDate': after['date'].isoformat()}
        ev.update(previousNativeExamText=ev['nativeExamText'], nativeExamText=new['exam'], calendarDate=after['date'].isoformat(),
                  weekday=after['date'].isoweekday(), startMinute=after['start'], endMinute=after['end'], classroomLiteral=after['room'],
                  currentRecheck={'checkedAt': '2026-10-23', 'sourceFile': CURRENT_REL, 'sourceSHA256': current_sha})

# 2) 시험 행이 들어간 날짜별 계획(v16·부분 계획) 4개
def entry(c, date):
    hits = [s for s in c['schedules'] if s['date'] == date]
    assert len(hits) == 1, (c['sourceId'], date)
    return hits[0]

e = entry(courses['AIE4011-01'], '2026-10-22'); assert e['classroom'] == 'AS510'; e['classroom'] = 'K401'
e = entry(courses['AIE4014-01'], '2026-10-22'); assert e['classroom'] == 'K201'; e['classroom'] = 'K201,K401'
e = entry(courses['EDU3033-01'], '2026-10-26'); assert (e['startMinute'], e['endMinute']) == (810, 885); e['endMinute'] = 900
dep = '교육문화연계전공'; t = courses['EDU3033-01']['departmentRemarks'][dep]; assert '공개된 75분 중간시험' in t
courses['EDU3033-01']['departmentRemarks'][dep] = t.replace('공개된 75분 중간시험', '공개된 90분 중간시험')
c = courses['CSE4115-01']; e = entry(c, '2026-10-23'); assert (e['startMinute'], e['endMinute'], e['classroom']) == (630, 705, 'K502')
c['schedules'].remove(e)
dep = '컴퓨터공학과'
c['departmentRemarks'][dep] += '\n2026-10-23 공식 조회에서 시험일자가 빠져 10/23 시험 시각(75분, K502)을 내렸습니다. 계획서의 8주차(10/23) 중간고사 표기는 시각이 없어 넣지 않습니다.'
report['scheduleEdits'] += [
    {'offering': 'AIE4011-01', 'change': '10/22 시험 강의실 AS510 -> K401'},
    {'offering': 'AIE4014-01', 'change': '10/22 시험 강의실 K201 -> K201,K401'},
    {'offering': 'EDU3033-01', 'change': '10/26 시험 종료 14:45 -> 15:00'},
    {'offering': 'CSE4115-01', 'change': '10/23 시험 행 삭제(공식 시험일자 삭제, 계획서에 시각 없음)'},
]

# 3) 공개 강의계획서가 대면 운영과 시각을 직접 적은 23강좌
MODE = {
    'AIEG118-01': '수업은 대면강의를 원칙으로', 'MGTG613-01': '수업은 대면강의를 원칙으로',
    'BIO2151-01': '수업방법 (%) 대면강의', 'CBE3013-01': '이론 강의는 주교재의 내용을 바탕으로 대면을 통해 진행한다',
    'CSE4115-02': '강의는 대면 수업을 원칙으로 하되', 'ECO2001-01': 'Classes will primarily be conducted through face-to-face instruction',
    'EEE3178-01': '오프라인 대면 강의 및 평가', 'SCE3178-01': '오프라인 대면 강의 및 평가', 'ETS2002-01': '1. 대면 수업이다.',
    'HFU4003-01': '수업은 대면 강의로 진행된다.', 'LCU4116-01': '대면 수업으로 진행된다.', 'LCU4116-02': '대면 수업으로 진행된다.',
    'LCU4117-01': '이번 학기는 학교 방침에 맞추어 대면 수업으로 진행된다.', 'LCU4117-02': '이번 학기는 학교 방침에 맞추어 대면 수업으로 진행된다.',
    'MAS2002-01': 'In-person meeting is the default mode of instruction.', 'MAS2003-01': '강의실 대면수업으로 진행합니다.',
    'MGT3001-04': 'The course will be conducted primarily in person.', 'MGT4507-01': '수업은 대면으로 진행하며',
    'PSY2003-01': '오프라인 강의입니다.', 'SHS2007-03': '대면 강의, 조별 토론 및 발표 등 조별 활동',
    'SHU4078-01': '학부 수강생은 대면 수업', 'STS2006-04': '1. 대면수업, 대면평가', 'STS2006-05': '이 수업은 100% 강의(대면 수업)로 운영',
}
# 계획서가 휴강이라고 직접 적었고 학교 학사일정에 같은 날 개강미사(9/10)가 있는 날
EXTRA_SKIP = {'ECO2001-01': ['2026-09-10'], 'SHS2007-03': ['2026-09-10']}
CLOCK = re.compile(r'(?:수업\s*시간|Class\s*Time|Class\s*Hours)\s*:?\s*.{0,40}?(?=수강\s*대상|담당\s*교수|강의실|수업\s*장소|Enrollment|Classroom|성\s*명|Name|$)', re.I)
PLAN_DIR = Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-c/sogang-current-public-plan-education')
CONTACT = re.compile(r'[\w.+-]+@[\w.-]*|https?://\S+|\d{2,4}-\d{3,4}(?:-\d{4})?')
for k, phrase in MODE.items():
    c = courses[k]
    hidden = 'publishedExamAppointmentEvidence' in c
    assert c['scheduleStatus'] == 'unrecognized' or hidden, k
    native = c['sourceEducationalMetadata']
    assert not any(native.get(f) for f in ('cyber', 'CU', 'CI', 'oddEven')), k
    # 오늘 받은 PDF가 10/8 사본과 같은 파일이므로, 연락처를 지운 10/8 교육용 본문에서 발췌한다.
    assert plan_log[k]['sha256'] == texts[k]['oldSha'], k
    text = re.sub(r'\s+', ' ', json.loads((PLAN_DIR / (k + '.json')).read_text())['educationalText'])
    m = re.search(r'\s*'.join(re.escape(ch) for ch in phrase.replace(' ', '')), text)
    assert m, (k, phrase)
    mode_excerpt = text[m.start():m.end() + 90].strip()
    assert not CONTACT.search(mode_excerpt) and not CONTACT.search(clock_text(text)), k
    clock = CLOCK.search(text[:1500]); assert clock, k
    extra = [datetime.date.fromisoformat(d) for d in EXTRA_SKIP.get(k, [])]
    regular = weekly(native['meetingText'], native['exam'], extra)
    schedules = sorted(regular + (c['schedules'] if hidden else []), key=lambda s: (s['date'], s['startMinute']))
    assert len({(s['date'], s['startMinute']) for s in schedules}) == len(schedules), k
    c['schedules'] = schedules
    c['scheduleStatus'] = 'scheduled'
    c['period'] = {'startDate': START.isoformat(), 'endDate': END.isoformat()}
    skip_note = ' 계획서가 휴강으로 적은 9/10(학교 학사일정의 개강미사)도 뺐습니다.' if extra else ''
    c['remarks'] = ('공개 강의계획서가 대면 운영과 수업 시각을 직접 적어 넣은 정규 주간 예약 계획입니다(2026-10-23 계획서 재확인). '
                    '현재 2026-2 원문 요일·실제 시작/종료 시각·강의실과 자체 개강9/1~겨울방학 전날12/21 범위에서 생성한 예약 날짜이며, 개별 강의계획이 직접 게시한 실제 출석 날짜가 아닙니다. '
                    '학교 중간시험10/20~26·기말시험12/15~21, 알려진 공휴일·11/20휴강, 9/18축제 운영 미확인일과 native 개별시험 날짜는 정규예약에서 제외했습니다.'
                    + skip_note + ' 정확한 시험 시각/실·보강·개별변경은 추정하지 않습니다. 사용자 강의방식3종은 유지합니다. 원문 비고: ' + native['remarks'])
    c['reservationEvidence'] = {
        'dateMeaning': 'derivedRegularWeeklyReservationNotSourcePublishedAttendance', 'sourceMeetingText': native['meetingText'],
        'ownTermStart': '2026-09-01', 'ownTermEnd': '2026-12-21', 'endBoundaryMeaning': 'dayBeforePublishedWinterVacation2026-12-22',
        'excludedNativeExamDates': sorted(d.isoformat() for d in exam_dates(native['exam'])),
        'excludedPlanStatedNoClassDates': EXTRA_SKIP.get(k, []),
        'sourceWeekIndexUsed': False, 'sourcePublishedIndividualDatesClaim': False, 'sourcePlanSHA256': plan_log[k]['sha256'],
        'planDirectStatement': {'checkedAt': '2026-10-23', 'operatingModeExcerpt': mode_excerpt, 'clockExcerpt': clock.group(0).strip()},
    }
    if hidden:
        ev = c['publishedExamAppointmentEvidence']
        ev['regularTeachingOperationStillUnconfirmed'] = False
        ev['periodScopeSingleKnownExamDate'] = False
        exam = parse_exam(native['exam'])
        for dep, t in c['departmentRemarks'].items():
            c['departmentRemarks'][dep] = t[:hidden_match(t).start()] + (hidden_sentence(exam).replace('약속만 제공', '약속')
                + ' 공개 강의계획서가 대면 수업과 수업 시각을 직접 적어 정규 주간 예약을 함께 넣었습니다. 실제 출석 날짜가 아닙니다.')
    report['resolved'].append({'offering': k, 'before': 'publishedExamOnly' if hidden else 'unrecognized', 'meetingText': native['meetingText'],
                               'regularDates': len(regular), 'extraSkip': EXTRA_SKIP.get(k, []), 'modeExcerpt': mode_excerpt, 'clockExcerpt': clock.group(0).strip()})

data['publishedDate'] = '2026-10-23'
data['publishedExamAppointmentOnlyAdditionCount'] = sum(
    1 for c in data['courses'] if 'publishedExamAppointmentEvidence' in c and 'reservationEvidence' not in c)
asset_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
import collections
report['statusCounts'] = dict(collections.Counter(c['scheduleStatus'] for c in data['courses']))
report['examOnly'] = data['publishedExamAppointmentOnlyAdditionCount']
(work / 'data/update-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
print(json.dumps({k: (len(v) if isinstance(v, list) else v) for k, v in report.items()}, ensure_ascii=False))
