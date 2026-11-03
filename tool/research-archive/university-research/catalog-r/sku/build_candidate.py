"""2026-2 public book reservations. No portal, inferred code, or attendance."""
import collections
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = ROOT.parents[1] / 'catalog-l'

def load(path):
    return json.loads(path.read_text())

def save(name, data):
    (ROOT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

def compact(value):
    return re.sub(r'\s+', '', value)

tables = load(SOURCE / 'skuniv-2026-2-all-20260826v2-tables.json')
native = load(SOURCE / 'skuniv-2026-2-course-rows-research.json')
headers = {t['index']: {str(c['col']): compact(''.join(c['paragraphs']))
                      for c in t['cells'] if c['row'] == 0} for t in tables}
clocks = {}
for cell in tables[207]['cells']:
    text = compact(''.join(cell['paragraphs']))
    m = re.fullmatch(r'(\d+)교시\(?(\d{2}):(\d{2})-(\d{2}):(\d{2})\)?', text)
    if m:
        clocks[int(m[1])] = [int(m[2]) * 60 + int(m[3]), int(m[4]) * 60 + int(m[5])]
assert set(clocks) == set(range(1, 10)) | set(range(21, 27))
book_text = (SOURCE / 'skuniv-2026-2-all-20260826v2.txt').read_text()
document_notes = [dict(sourceLine=i + 1, nativeText=line)
                  for i, line in enumerate(book_text.splitlines())
                  if line.startswith('※') and not re.search(r'\d{2,4}-\d{3,4}|@|문의', line)]
assert '2026학년도 2학기' in (SOURCE / 'skuniv-2026-2-all-20260826v2.txt').read_text()[
    (SOURCE / 'skuniv-2026-2-all-20260826v2.txt').read_text().rfind('강의시간표'):]

closures = []
for kind, notice in [('first', 66430), ('final', 66914)]:
    sheet = next(iter(load(SOURCE / f'skuniv-2026-2-{kind}-closure.json').values()))
    for values in sheet[2:]:
        if len(values) > 3 and isinstance(values[2], str) and re.fullmatch(r'[A-Z0-9]{6}', values[2]):
            closures.append(dict(noticeUrl=f'https://www.skuniv.ac.kr/notice/{notice}',
                                 nativeHeaders=sheet[1], nativeEducationalRow=values,
                                 courseCode=values[2], section=str(values[3] or '')))
closed = {(x['courseCode'], x['section']) for x in closures}
assert len(closed) == 104
calendar_path = Path('/private/tmp/daily-skuniv-calendar.json')
if calendar_path.exists():
    calendar = load(calendar_path)
    events = [dict(title=x['summary'], startDate=x['start']['date'], endExclusive=x['end']['date'])
              for x in calendar['items'] if x.get('start', {}).get('date', '').startswith(
                  ('2026-09', '2026-10', '2026-11', '2026-12')) and '교원' not in x['summary']]
    calendar_updated = calendar['updated']
else:
    prior_source = load(ROOT / 'sku-current-source-proof-v1.json')
    events = prior_source['academicEvents']
    calendar_updated = prior_source['calendarPublicUpdated']
save('sku-current-native-education-proof-v1.json', dict(
    rows=native, headers=headers, clockTable=tables[207], clocks=clocks,
    originalCourseTables=[tables[i] for i in sorted({x['table'] for x in native})],
    sourceDocumentEducationalFootnotes=document_notes,
    footnoteScope='Exact source lines; only explicitly named course/section/ROTC rules applied; other department-level paragraphs require contextual review',
    closureRows=closures, closureUnionCount=len(closed)))
save('sku-current-source-proof-v1.json', dict(
    reviewDate='2026-10-08', sourceUrl='https://www.skuniv.ac.kr/notice/65877',
    sourceFileSha256=hashlib.sha256((SOURCE / 'skuniv-2026-2-all-20260826v2.hwp').read_bytes()).hexdigest(),
    latestNoticeRecheck='Normal public GET October 8 by root; attachment509440 bytes unchanged',
    publishedDateMeaning='2026-08-26 revision identifier in current official attachment filename, not original notice publication time',
    currentWholePortalUpdatesVerified=False, sourceClockTableIndex=207,
    clockTitle='강의시간표 (교시 + 75분제) 2026학년도 2학기',
    calendarUrl='https://www.skuniv.ac.kr/academy-calendar?timeMin=2025-12-31T15%3A00%3A00.000Z&timeMax=2026-12-31T14%3A59%3A59.999Z',
    calendarPublicUpdated=calendar_updated, academicEvents=events,
    semesterBoundary=dict(startDate='2026-09-01', endDate='2026-12-15',
                          endDateMeaning='Derived day before official December16 winter vacation marker; not printed final teaching date'),
    regularReservationEndDate='2026-12-07',
    physicalCampusProof=dict(currentUrl='https://www.skuniv.ac.kr/notice/61233',
        currentPublishedDate='2026-02-23', building='혜인관', nativeRooms=['301','305','307','311','302','303','304'],
        mapAddress='서울시 성북구 서경로124',
        aliasSourceUrl='https://www.skuniv.ac.kr/notice/26503', aliasPublishedDate='2019-11-01',
        aliasMeaning='Historical official notice names 혜인관 and its existing (혜)-205, (혜)-209 rooms; used only for building alias, never historical clock or attendance'),
    accessScope='Official normal public notice and attachments; no login, account, session, staff hidden, contact or student roster stored',
    completionClaim=False, productionChange=False))

notes = ('공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 원문 학수번호·분반·학년·이수구분·수강대상·비고를 보존합니다. '
         '현재2026-2책 맨끝 교시표의 1~9교시50분/21~26교시75분만 사용하며 야간10~13교시는 미확인으로 보류합니다. '
         '원문 교시 사이 휴식은 각각 분리합니다. 방식 미지정으로 사용자의 선택을 유지합니다. '
         '9월1일 개강부터 기말시험 전12월7일까지 일반 예약이며 중간시험10월20~26일과 공휴일은 제외합니다. '
         '10월22일 개교기념일은 원문 정상수업 안내이며 휴일로 해석하지 않습니다(이 후보에서는 중간시험 범위로 예약 제외). '
         '실제 개별 중간·기말시험/보강일은 생성하지 않습니다. 학기경계12월15일은 공식12월16일 동계방학 전날로 도출했으며 인쇄된 종강일이 아닙니다. '
         '공개 1차·2차 최종폐강104개 분반을 대조했으나 이후 포털의 최신 전체 변경은 미확인입니다. ')
campuses = collections.defaultdict(list)
held = collections.Counter()
for row in native:
    index = row['table']; head = headers[index]; cells = row['cells']
    def field(label):
        return next((cells.get(k, '') for k, v in head.items() if v == label), '')
    def normalized(label):
        return compact(field(label))
    code = normalized('학수번호'); section = normalized('분반'); title = field('교과목명').strip()
    classification = field('이수구분')
    if not classification and index != 49:
        classification = next((cells.get(k, '') for k, v in head.items() if v == '구분'), '')
    classification = compact(classification)
    schedule = next((cells.get(k, '') for k, v in head.items() if v.startswith('요일') or (v == '시간' and int(k) > 6)), '')
    room = field('강의실').strip(); raw_time = compact(schedule)
    title_table = next(t for t in reversed(tables[:index]) if len(t['cells']) == 1)
    department_native = [''.join(c['paragraphs']) for c in title_table['cells']]
    department = ' / '.join(x.strip() for x in department_native)
    campus = 'main' if room.startswith(('혜-', '혜인관')) else 'unknown'
    reason = ''; spans = []
    original_notes = field('비고') or field('신입생대상학과')
    if (code, section) in closed:
        reason = '현재 공개 1차·2차 최종 폐강 분반'
    elif re.search(r'집중|현장|인턴|사회봉사|연주와봉사|스키|스노우보드', compact(title + original_notes)):
        reason = '집중·현장·봉사·인턴 실제 운영 날짜 미확인'
    elif 'OCU' in raw_time or '원격' in compact(room):
        reason = '공개 원격·OCU 실제 운영 시각·날짜 미확인'
    elif not raw_time:
        reason = '요일·교시 미공개'
    else:
        groups = list(re.finditer(r'([월화수목금토일]+)(\d+(?:\.\d+)*)', raw_time))
        if ''.join(x[0] for x in groups) != raw_time:
            reason = '원문 요일·교시 대응 미확인'
        elif any(int(p) not in clocks for x in groups for p in x[2].split('.')):
            reason = '현재 공식 교시표에 없는 야간·기타 교시 시각 미확인'
        elif any(d in '토일' for x in groups for d in x[1]):
            reason = '주말 실제 운영 날짜 미확인'
        elif not room:
            reason = '원문 강의실 미공개'
        else:
            for group in groups:
                for day in group[1]:
                    for p in group[2].split('.'):
                        start, end = clocks[int(p)]
                        spans.append(dict(weekday='월화수목금토일'.index(day)+1,
                                          startMinute=start, endMinute=end, classroom=room))
            if len({tuple(x.values()) for x in spans}) != len(spans):
                reason = '같은 원문 행 중복 교시'; spans = []
    appointments = []
    if not reason:
        day = dt.date(2026,9,1)
        while day <= dt.date(2026,12,7):
            if not (dt.date(2026,10,20) <= day <= dt.date(2026,10,26)) and day.isoformat() not in [
                '2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-10-23']:
                appointments.extend(dict(s, date=day.isoformat()) for s in spans if s['weekday']==day.isoweekday())
            day += dt.timedelta(days=1)
    else:
        held[reason] += 1
    credits_raw = compact(field('학점'))
    credits = float(credits_raw) if re.fullmatch(r'\d+(?:\.\d+)?', credits_raw) else None
    source_fields = ' / '.join(f'{head[k]}[{k}]:{value}' for k, value in cells.items())
    remarks = notes + ('강의실 약호의 실제 캠퍼스는 미확인으로 별도 미확인 자료 묶음에 보존합니다. ' if campus=='unknown' else '공식 혜인관 명칭·약호와 현재 본교 지도를 대조했습니다. ')
    remarks += '원문 표 제목: ' + department + ' / 원문 교육 필드: ' + source_fields
    relevant_notes = []
    if index <= 47 and section in ['60', '61']:
        relevant_notes.extend(x['nativeText'] for x in document_notes
                              if f'교양 {section}' in x['nativeText'] or ('교양 60, 61' in x['nativeText'] and section == '61'))
    if index == 49:
        relevant_notes.extend(x['nativeText'] for x in document_notes if x['nativeText'].startswith('※ ROTC 교과목'))
    if compact(title).startswith('졸업'):
        relevant_notes.extend(x['nativeText'] for x in document_notes
                              if compact(x['nativeText']).startswith('※' + compact(title) + '은반드시2026'))
    relevant_notes = list(dict.fromkeys(relevant_notes))
    if relevant_notes:
        remarks += ' / 문서의 명시된 교과목·분반 안내: ' + ' / '.join(relevant_notes)
    if reason: remarks += ' / 예약 보류: ' + reason
    campuses[campus].append(dict(sourceId=f'sku/{campus}/2026-2/{code}-{section}/t{index}-r{row["row"]}',
        campus=campus, academicYear=2026, semester='2', courseCode=code, section=section,
        courseName=title, professor=field('담당교수').strip(), classification=classification, credits=credits,
        departments=[department], departmentCredits={}, departmentClassifications={},
        sourceSchedule=schedule, sourceClassroom=room, remarks=remarks,
        scheduleStatus='scheduled' if appointments else 'unrecognized', schedules=appointments,
        period=dict(startDate='2026-09-01',endDate='2026-12-15'),
        metadata=dict(originalEducationalRow=row, nativeHeaders=head, sourceDepartmentTitle=department_native,
            sourceMergedCells=[c for c in tables[index]['cells']
                               if c['row'] <= row['row'] < c['row'] + c['rowSpan']],
            nativeClassification=classification, nativeGrade=field('학년'), nativeCredits=field('학점'),
            sourceCodePublished=True, sourceSectionPublished=bool(section), referenceKind='nativeCourseCode',
            sourceOriginalTableIndex=index, sourceOriginalRow=row['row'], closureMatched=(code,section) in closed,
            explicitlyNamedDocumentNotes=relevant_notes,
            actualAttendanceConfirmed=False, actualPhysicalDatesConfirmed=False, currentWholePortalUpdatesVerified=False,
            deliveryModeStatus='unknown-user-choice', researchOnly=True, heldReason=reason)))

stats = {}
for campus, courses in campuses.items():
    save(f'sku-{campus}-2026-2.reservation-planned-v1.json',dict(schemaVersion=2,universityId='sku',
         campus=campus,campusName='본교·혜인관' if campus=='main' else '캠퍼스 미확인 자료',
         academicYear=2026,semester='2',publishedDate='2026-08-26',sourceUrl='https://www.skuniv.ac.kr/notice/65877',
         researchOnly=True,completionClaim=False,courses=courses))
    stats[campus]=dict(rows=len(courses),scheduled=sum(bool(x['schedules']) for x in courses),
                       appointments=sum(len(x['schedules']) for x in courses))
save('sku-reservation-planned-v1-audit.json',dict(campuses=stats,heldReasons=held,
     nativeRowCount=len(native),closureUnionCount=len(closed),completionClaim=False))
print(json.dumps(dict(campuses=stats,held=held),ensure_ascii=False))
