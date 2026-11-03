"""Extend immutable v1 from normal published notice then unencrypted HWP."""
from pathlib import Path
from datetime import date, timedelta
import hashlib
import http.cookiejar
import importlib.util
import json
import re
import urllib.request

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
prior_path = ROOT / 'cbnu-main-2026-2.korean-track-partial-v1.json'
out = json.loads(prior_path.read_text())
prior = json.loads(prior_path.read_text())
audit_v1 = json.loads((ROOT / 'cbnu-korean-track-partial-v1-audit.json').read_text())
notice = 'https://public.cbnu.ac.kr/post/2095?category_id=5&page=5'
download = 'https://public.cbnu.ac.kr/postact/download/3505'
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
notice_body = opener.open(notice, timeout=45).read()
response = opener.open(urllib.request.Request(download, headers={'Referer': notice}), timeout=45)
body = response.read()
if not body.startswith(bytes.fromhex('d0cf11e0a1b11ae1')):
    raise ValueError('Normal published download did not return standard HWP; stop')
reader_path = REPO / 'work/university-research/catalog-g/read_skku_published_office_plan.py'
spec = importlib.util.spec_from_file_location('published_office', reader_path)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
text = '\n'.join(line.strip() for line in reader.hwp_text(body).splitlines())
assert '2026년 일반 2학기 행정학과 1학년' in text
matches = list(re.finditer(r'([^\n]+)\n(\d{7})-(\d{2})\n([^\n]+)\n([EN]\d+-\d+)\n([월화수목금토])\s*(\d{1,2})', text))
assert len(matches) == 18
education = []
grouped = {}
for match in matches:
    title, code, section, professor, room, day, native_period = match.groups()
    row = {'courseName': title.strip(), 'courseCode': code, 'section': section, 'professor': professor.strip(), 'classroom': room, 'weekday': day, 'nativePeriod': int(native_period)}
    education.append(row)
    grouped.setdefault(code + '-' + section, []).append(row)
assert len(grouped) == 6
closed = json.loads((ROOT / 'cbnu-current-closure-education-20261008.json').read_text())
closed_ids = {c['courseCode'] + '-' + c['section'] for c in closed['closedCourses']}
excluded = {cid: rows for cid, rows in grouped.items() if cid in closed_ids}
assert set(excluded) == {'0912002-10'}
active = {cid: rows for cid, rows in grouped.items() if cid not in closed_ids}
assert len(active) == 5
period_map = {}
for match in re.finditer(r'(\d+)교시\s*\n(\d{2}):(\d{2})\s*\n~\s*\n(\d{2}):(\d{2})', text):
    p, sh, sm, eh, em = map(int, match.groups())
    start, end = sh * 60 + sm, eh * 60 + em
    if end - start == 50:
        period_map[p] = {'startMinute': start, 'endMinute': end}
assert period_map[8] == {'startMinute': 960, 'endMinute': 1010}
evidence = {'noticeUrl': notice, 'noticeSHA256': hashlib.sha256(notice_body).hexdigest(), 'publishedDate': '2026-07-27', 'attachmentUrl': download, 'attachmentSHA256': hashlib.sha256(body).hexdigest(), 'nativeTermHeading': '2026년 일반 2학기 행정학과 1학년', 'publicEducationRows': education, 'fiftyMinutePeriodMap': period_map, 'closedNativeIdsExcluded': sorted(excluded), 'normalPublicDownload': 'Notice read then observed download button with transient in-memory public cookie jar; no login or cookie values persisted', 'protectedDocument': False, 'rawAttachmentOrStaffHeaderSaved': False}
evidence_path = ROOT / 'cbnu-current-admin-public-education-20261008.json'
evidence_path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
first, last = date(2026, 9, 1), date(2026, 12, 6)
days = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6}
for cid, rows in active.items():
    first_row = rows[0]
    assert len({r['weekday'] for r in rows}) == 1
    assert len({r['classroom'] for r in rows}) == 1
    assert len({r['professor'] for r in rows}) == 1
    weekday = days[first_row['weekday']]
    slots = sorted(r['nativePeriod'] for r in rows)
    assert slots in [[2, 3, 4], [7, 8, 9], [8, 9, 10]]
    meetings = []
    current = first
    while current <= last:
        if current.isoweekday() == weekday and current.isoformat() not in audit_v1['excludedHolidays']:
            for slot in slots:
                meetings.append({'date': current.isoformat(), 'weekday': weekday, **period_map[slot], 'classroom': first_row['classroom']})
        current += timedelta(days=1)
    note = '수강 대상: 행정학과 1학년 공개 신입생 대리수강신청 계획. 공개 주간 예약 계획, 실제 운영/날짜 미확인. 공지에 적힌 50분 교시·강의실을 이번 학기 개강일 이후 12월 6일까지 예약 계획으로 반영했습니다. 교시 사이 10분 휴식은 유지합니다. 학교 정기 휴업일을 제외했으며 실제 보강, 집중/영상/실시간 운영은 확인 중입니다. 12월 7~18일 기말시험 권장 기간은 실제 운영 확인 전까지 보류했습니다. 학점과 이수구분은 이 첨부에 기재되어 있지 않습니다. 수강 조건과 변경 여부는 학교 공지를 확인해야 합니다.'
    schedule_text = first_row['weekday'] + ' ' + ', '.join(f"{period_map[s]['startMinute']//60:02}:00-{period_map[s]['endMinute']//60:02}:50" for s in slots)
    course = {'sourceId': f'cbnu/main/2026-2/{cid}', 'campus': 'main', 'academicYear': 2026, 'semester': '2', 'courseCode': first_row['courseCode'], 'courseName': first_row['courseName'], 'courseNameAliases': sorted({r['courseName'] for r in rows} - {first_row['courseName']}), 'section': first_row['section'], 'professor': first_row['professor'], 'classification': '', 'departmentClassifications': {}, 'credits': None, 'departmentCredits': {}, 'departments': ['행정학과'], 'departmentRemarks': {'행정학과': note}, 'sourceSchedule': schedule_text, 'sourceClassroom': first_row['classroom'], 'scheduleStatus': 'scheduled', 'schedules': meetings, 'period': {'startDate': first.isoformat(), 'endDate': last.isoformat()}, 'sourceEducation': {'nativeCourseId': cid, 'numericSectionIndividuallyPrinted': True, 'nativePeriods': slots, 'nativePublicCells': rows, 'creditsPublished': False, 'classificationPublished': False, 'sourceModePublished': False, 'physicalCampusIndividuallyPrinted': False, 'sourceAttachmentUrl': download, 'partialSchedule': True, 'allMeetingsIndividuallyPrinted': False, 'dateBasis': 'Current weekly public reservation plan and official opening, not individually confirmed attendance', 'operatingReviewComplete': False, 'closureChecked': True, 'remainingScheduleReason': 'Actual teacher-plan operating dates, delivery, makeup and intensive cases remain unknown'}}
    out['courses'].append(course)

out['campusName'] = '본교'
out['candidateRevision'] = 'korean-admin-partial-v2'
out['campusScopeBasis'] = 'Institution main scope only; physical campus not individually printed by these course sources'
for course in out['courses']:
    course['sourceEducation']['physicalCampusIndividuallyPrinted'] = False
target = ROOT / 'cbnu-main-2026-2.korean-admin-partial-v2.json'
target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
lookup = {c['sourceId']: c for c in out['courses']}
assert all(lookup[c['sourceId']]['schedules'] == c['schedules'] for c in prior['courses'])
assert len(out['courses']) == 11
assert sum(len(c['schedules']) for c in out['courses']) == 435
audit = {**audit_v1, 'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'priorV1CandidateSHA256': hashlib.sha256(prior_path.read_bytes()).hexdigest(), 'adminEducationSHA256': hashlib.sha256(evidence_path.read_bytes()).hexdigest(), 'nativeCourses': 11, 'dated50MinuteReservationSlots': 435, 'datedCourseOccurrences': 145, 'prior6SchedulesExactlyPreserved': True, 'closedNativeCoursesExcluded': sorted(excluded), 'physicalCampusIndividuallyPrinted': False, 'campusScope': 'Institution main scope only', 'new5Courses': [{'nativeCourseId': cid, 'reservationSlots': len(lookup[f'cbnu/main/2026-2/{cid}']['schedules'])} for cid in active]}
(ROOT / 'cbnu-korean-admin-partial-v2-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: audit[k] for k in ['candidateSHA256', 'nativeCourses', 'dated50MinuteReservationSlots', 'datedCourseOccurrences', 'closedNativeCoursesExcluded']})
