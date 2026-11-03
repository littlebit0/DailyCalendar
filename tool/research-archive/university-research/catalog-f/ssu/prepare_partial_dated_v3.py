"""Four additional current plans, only printed dates with resolved delivery."""
from pathlib import Path
from datetime import date
import json, re, hashlib

ROOT = Path(__file__).resolve().parent
prior_path = ROOT / 'ssu-main-2026-2.whole2219-partial-dated-v2.json'
out = json.loads(prior_path.read_text())
source_path = ROOT / 'ssu-current-public-korean-major-next20-plans-20261008.json'
source = json.loads(source_path.read_text())
assert source['all20RequestedPlansReviewed']
plans = {p['nativeCourseId']: p for p in source['publicTeachingFields']}
courses = {c['sourceEducation']['nativeTenDigitCourseId']: c for c in out['courses']}
for cid, plan in plans.items():
    courses[cid]['sourceEducation']['currentPublicTeachingPlan'] = plan
    courses[cid]['sourceEducation']['currentSubsetRechecked'] = True
    assert plan['academicYear'] == 2026 and plan['semester'] == '2'
    assert plan['numericSection'] == cid[-2:]

configuration = {
    '2150542401': {'start': 540, 'end': 615, 'rooms': {1: '미래관 20201', 3: '미래관 20201'}, 'first': '2026-09-02', 'last': '2026-12-14', 'meetingCount': 26, 'printedCount': 30, 'mixedWeek15': True},
    '2150222901': {'start': 720, 'end': 795, 'rooms': {2: '조만식기념관 12312', 4: '조만식기념관 12312'}, 'first': '2026-09-01', 'last': '2026-12-10', 'meetingCount': 25, 'printedCount': 27},
    '2150569301': {'start': 720, 'end': 795, 'rooms': {2: '미래관 20303', 4: '미래관 20304'}, 'first': '2026-09-01', 'last': '2026-12-10', 'meetingCount': 26, 'printedCount': 30},
    '2150551501': {'start': 630, 'end': 705, 'rooms': {2: '미래관 20201', 4: '미래관 20201'}, 'first': '2026-09-01', 'last': '2026-12-10', 'meetingCount': 4, 'printedCount': 6},
}
audit_courses = []
for cid, config in configuration.items():
    course = courses[cid]
    text = plans[cid]['weeklyTeachingPlan']
    if cid in ['2150542401', '2150569301']:
        matches = list(re.finditer(r'■\s*<(\d+)주차\s*-?\s*(\d+)월\s*(\d+)일[^>]*>', text))
        entries = [(int(m[2]), int(m[3]), int(m[1]), m.end(), matches[i+1].start() if i+1 < len(matches) else len(text)) for i, m in enumerate(matches)]
    else:
        matches = list(re.finditer(r'\((\d{1,2})/(\d{1,2})\)', text))
        entries = [(int(m[1]), int(m[2]), None, m.end(), matches[i+1].start() if i+1 < len(matches) else len(text)) for i, m in enumerate(matches)]
    assert len(entries) == config['printedCount'], cid
    schedule = course['sourceSchedule']
    clock = f"{config['start']//60:02}:{config['start']%60:02}-{config['end']//60:02}:{config['end']%60:02}"
    assert clock in schedule and all(room in schedule for room in config['rooms'].values())
    meetings, held = [], []
    for month, day, native_week, start, end in entries:
        current_date = date(2026, month, day)
        content = text[start:end].strip()
        reason = None
        if content.startswith('동영상 강의'):
            reason = 'Video lecture explicitly printed; no actual viewing clock/window published'
        elif config.get('mixedWeek15') and native_week == 15:
            assert '15[학습동영상+대면시험]' in text
            reason = 'Week15 explicitly mixes recorded learning and physical exam; exact per-date delivery or actual exam clock unresolved'
        elif re.match(r'^(중간|기말)고사(?!\s*(풀이|전 복습))', content):
            reason = 'Exam date printed; actual exam clock not separately confirmed'
        if reason:
            held.append({'date': current_date.isoformat(), 'nativeWeekOrdinal': native_week, 'sourceTeachingContent': content, 'reason': reason})
            continue
        weekday = current_date.isoweekday()
        assert weekday in config['rooms'], (cid, current_date)
        meetings.append({'date': current_date.isoformat(), 'weekday': weekday, 'startMinute': config['start'], 'endMinute': config['end'], 'classroom': config['rooms'][weekday], 'deliveryMode': 'inPerson'})
    assert len(meetings) == config['meetingCount'], cid
    if cid in ['2150222901', '2150551501']:
        for excluded, reason in [('2026-09-24', 'Explicit video lecture with unposted viewing clock'), ('2026-10-20', 'Explicit self-study instead of physical class'), ('2026-12-08', 'Explicit self-study instead of physical class')]:
            assert not any(m['date'] == excluded for m in meetings)
            held.append({'date': excluded, 'reason': reason})
    course.update({'schedules': meetings, 'scheduleStatus': 'scheduled', 'period': {'startDate': config['first'], 'endDate': config['last']}})
    note = '현재 강의계획에 직접 적힌 날짜와 같은 과목의 공개 시간표 시각·강의실만 반영했습니다. 영상 수업은 실제 시청 시각이 미공개이면 추가하지 않았고, 시험은 실제 시험 시각 확인 전까지 보류했습니다. 주차 번호만 있는 수업 날짜나 자율학습을 대면 수업으로 추가하지 않았습니다.'
    if cid == '2150542401':
        note += ' 10월 5일 영상 수업, 11월 2일 중간고사 및 15주차 학습동영상·대면시험 혼합 운영의 12월 9일·14일은 보류했습니다. 12월 7일은 기말고사 전 복습 수업입니다.'
    elif cid == '2150569301':
        note += ' 9월 24일·10월 1일은 영상 수업입니다. 11월 5일·12월 8일 시험은 보류했으며, 11월 3일 복습과 11월 10일·12월 10일 시험 풀이 수업은 유지했습니다.'
    elif cid == '2150222901':
        note += ' 9월 24일은 영상 수업, 10월 20일·12월 8일은 자율학습입니다. 10월 22일·12월 10일 시험은 보류했습니다.'
    else:
        note += ' 날짜가 직접 기재된 9월 1일·3일·8일·10일 수업 4회만 반영했습니다. 이후 주차의 일반 수업 날짜는 확인 중입니다. 9월 24일 영상, 10월 20일·12월 8일 자율학습, 10월 22일·12월 10일 시험을 대면 수업으로 추가하지 않았습니다.'
    prior_note = '현재 공개 강의의 수강 조건을 보존했습니다. 개별 수업 운영 검토 전으로 자동 시간표 추가는 아직 지원하지 않습니다.'
    for department, remarks in course['departmentRemarks'].items():
        assert prior_note in remarks
        course['departmentRemarks'][department] = remarks.replace(prior_note, note)
    course['sourceEducation'].update({'partialSchedule': True, 'allMeetingsIndividuallyPrinted': False, 'dateBasis': 'Each date printed in current teacher plan; clocks/rooms only same native current public timetable weekday', 'heldOperatingRows': held, 'operatingReviewComplete': False, 'remainingScheduleReason': 'Source explicit video/self-study/mixed/exam cases and unspecified ordinary dates held'})
    audit_courses.append({'nativeCourseId': cid, 'meetingCount': len(meetings), 'newDatedMeetings': meetings, 'heldOperatingRows': held})

out['candidateRevision'] = 'partial-dated-v3'
out['currentPublicRecheckScope'] = '12 small-group chapel and32 Korean major course rows;36 public teacher plans, whole2219 current requery incomplete.'
target = ROOT / 'ssu-main-2026-2.whole2219-partial-dated-v3.json'
target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
prior = json.loads(prior_path.read_text())
assert all(courses[c['sourceEducation']['nativeTenDigitCourseId']]['schedules'] == c['schedules'] for c in prior['courses'] if c['schedules'])
audit = {'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'priorV2CandidateSHA256': hashlib.sha256(prior_path.read_bytes()).hexdigest(), 'new20PlanEvidenceSHA256': hashlib.sha256(source_path.read_bytes()).hexdigest(), 'wholeNativeCourses': 2219, 'scheduledCourses': 17, 'datedMeetings': 121, 'heldCourses': 2202, 'currentPublicRowsRechecked': 44, 'currentPublicTeacherPlans': 36, 'prior13Courses40DatesExactlyUnchanged': True, 'newCourses': audit_courses, 'productionModified': False, 'installed': False, 'completionClaim': False}
assert sum(len(c['schedules']) for c in out['courses']) == 121
(ROOT / 'ssu-whole2219-partial-dated-v3-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k != 'newCourses'})
