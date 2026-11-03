"""Keep first12 fallback, add one genuinely dated current teaching plan."""
from pathlib import Path
from datetime import date
import json, re, hashlib

ROOT = Path(__file__).resolve().parent
base_path = ROOT / 'ssu-main-2026-2.whole2219-partial-first12-v1.json'
out = json.loads(base_path.read_text())
chapel = json.loads((ROOT / 'ssu-current-public-chapel-plans-20261008.json').read_text())
major = json.loads((ROOT / 'ssu-current-public-korean-major-plans-20261008.json').read_text())
plans = {p['nativeCourseId']: p for p in chapel['publicTeachingFields'] + major['publicTeachingFields']}
courses = {c['sourceEducation']['nativeTenDigitCourseId']: c for c in out['courses']}
for cid, plan in plans.items():
    courses[cid]['sourceEducation']['currentPublicTeachingPlan'] = plan
    courses[cid]['sourceEducation']['currentSubsetRechecked'] = True
    assert plan['academicYear'] == 2026 and plan['semester'] == '2'
    assert plan['numericSection'] == cid[-2:]

cid = '2150523201'
course = courses[cid]
plan = plans[cid]['weeklyTeachingPlan']
# Every date is printed inside this course's current teacher plan. The published
# public timetable supplies its own weekday-specific 13:30-14:45 rooms.
entries = list(re.finditer(r'■\s*<(\d+)주차\s*(\d+)월\s*(\d+)일[^>]*>', plan))
assert len(entries) == 30
source_clock = course['sourceSchedule']
assert '월 13:30-14:45 (미래관 20206-임채훈)' in source_clock
assert '수 13:30-14:45 (미래관 20201-임채훈)' in source_clock
meetings, held = [], []
for i, entry in enumerate(entries):
    current_date = date(2026, int(entry[2]), int(entry[3]))
    content = plan[entry.end():entries[i+1].start() if i+1<len(entries) else len(plan)]
    reason = None
    if content.startswith(' 동영상 강의') or content.startswith('동영상 강의'):
        reason = 'Video lecture explicitly printed; no actual viewing clock/window published'
    elif content.strip().startswith('기말고사') and not content.strip().startswith('기말고사 풀이'):
        reason = 'Exam date printed; actual exam clock not separately confirmed'
    if reason:
        held.append({'date': current_date.isoformat(), 'nativeWeekOrdinal': int(entry[1]), 'sourceTeachingContent': content, 'reason': reason})
        continue
    weekday = current_date.isoweekday()
    assert weekday in [1, 3]
    meetings.append({'date': current_date.isoformat(), 'weekday': weekday, 'startMinute': 810, 'endMinute': 885, 'classroom': '미래관 20206' if weekday == 1 else '미래관 20201', 'deliveryMode': 'inPerson'})
assert len(meetings) == 28
assert {h['date'] for h in held} == {'2026-10-05', '2026-12-07'}
assert meetings[-1]['date'] == '2026-12-16'
assert not any(m['date'] in {'2026-12-14', '2026-12-21'} for m in meetings)
course['schedules'] = meetings
course['scheduleStatus'] = 'scheduled'
course['period'] = {'startDate': '2026-09-02', 'endDate': '2026-12-16'}
note = '현재 강의계획에 직접 기재된 수업 날짜와 공개 시간표의 해당 요일 시각·강의실을 반영했습니다. 10월 5일은 동영상 강의로 대면 일정을 추가하지 않았으며 시청 시각은 미공개입니다. 12월 7일 기말고사는 날짜만 확인되어 시험 시각 확인 전까지 추가하지 않았습니다. 마지막 수업은 12월 16일이며 12월 14일·21일 수업을 임의로 추가하지 않았습니다.'
for department, remarks in course['departmentRemarks'].items():
    previous_note = '현재 공개 강의의 수강 조건을 보존했습니다. 개별 수업 운영 검토 전으로 자동 시간표 추가는 아직 지원하지 않습니다.'
    course['departmentRemarks'][department] = remarks.replace(previous_note, note)
course['sourceEducation'].update({'partialSchedule': True, 'allMeetingsIndividuallyPrinted': False, 'dateBasis': 'Each date printed in current teacher plan; clock and room joined only to same native current public timetable weekday', 'heldOperatingRows': held, 'operatingReviewComplete': False, 'remainingScheduleReason': 'Oct5 untimed video viewing and Dec7 actual exam clock remain unknown'})
out['currentPublicRecheckScope'] = '12 small-group chapel and32 Korean major course rows;16 public teacher plans, whole2219 current requery incomplete.'
out['candidateRevision'] = 'partial-dated-v2'
target = ROOT / 'ssu-main-2026-2.whole2219-partial-dated-v2.json'
target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
audit = {'candidateSHA256': hashlib.sha256(target.read_bytes()).hexdigest(), 'priorFirst12CandidateSHA256': hashlib.sha256(base_path.read_bytes()).hexdigest(), 'wholeNativeCourses': 2219, 'scheduledCourses': 13, 'datedMeetings': 40, 'heldCourses': 2206, 'currentPublicRowsRechecked': 44, 'currentPublicTeacherPlans': 16, 'newDatedCourse': cid, 'newDatedMeetings': meetings, 'heldOperatingRows': held, 'prior12MeetingsExactlyUnchanged': all(courses[c['sourceEducation']['nativeTenDigitCourseId']]['schedules'] == c['schedules'] for c in json.loads(base_path.read_text())['courses'] if c['schedules']), 'wholeUniversitySupportComplete': False, 'productionModified': False, 'installed': False}
assert audit['prior12MeetingsExactlyUnchanged']
(ROOT / 'ssu-whole2219-partial-dated-v2-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print({k: v for k, v in audit.items() if k not in ['newDatedMeetings', 'heldOperatingRows']})
