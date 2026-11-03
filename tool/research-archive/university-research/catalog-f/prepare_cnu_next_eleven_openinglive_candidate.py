"""Research checkpoint: add only one current printed first-class date; never repeat."""
import json, hashlib, datetime
from pathlib import Path
R = Path(__file__).resolve().parent
source = R / 'cnu-unknown-2026-2.whole-checkpoint-next-ten-firstday-partial.json'
old = json.loads(source.read_text())
new = json.loads(source.read_text())
cid = '1004-7005-01'
c = next(c for c in new['courses'] if c['sourceEducation']['courseId'] == cid)
plan = json.loads((R / 'cnu-one-openinglive-current-education-recheck' / f'{cid}.json').read_text())
header = plan['header'][0]
assert '강의 첫 주는 ZOOM 으로 실시간 강의로 진행됩니다.' in header['LSN_OPER_MTHD']
assert '개강일 강의정보' in header['LSN_OPER_MTHD']
assert '반드시 접속할 것' in header['LSN_OPER_MTHD']
assert header['TLSN_ANNM'] == '화10:00~12:00(교408), 금16:00~18:00(교408)'
assert c['academicYear'] == 2026
metadata = c['sourceEducation']['originalEducationFields']
assert str(metadata['OPEN_YR']) == '2026'
assert c['sourceEducation']['courseId'] == cid
assert str(c['semester']) == '2'
public_row = next(row for row in json.loads((R / 'cnu-current-catalog-education-with-public-names.json').read_text()) if row['COURSE_NO'] == cid)
assert public_row['LT_STAFF_NM'] == c['professor']
assert public_row['SBJT_NM'] == c['courseName']
assert str(public_row['CLOSE_YN']) == '0'
clocks = json.loads((R / 'cnu-current-clock-projection.json').read_text())
clock = next(m for r in clocks if r['courseId'] == cid for m in r['actualClockMeetings'] if m['weekday'] == 2)
assert clock['startMinute'] == 600 and clock['endMinute'] == 720 and clock['location'] == '교408'
assert datetime.date(2026, 9, 1).isoweekday() == 2
c['scheduleStatus'] = 'scheduled'
c['period'] = {'startDate': '2026-09-01', 'endDate': '2026-09-01'}
c['schedules'] = [{'date': '2026-09-01', 'weekday': 2, 'startMinute': 600, 'endMinute': 720, 'classroom': '', 'deliveryMode': 'liveOnline'}]
e = c['sourceEducation']
e.pop('derivedBlockingExplanation', None)
e.update(registrationStatus='partiallyScheduledOpeningDayLiveOnly', individualReviewStatus='Current first-week live teaching and mandatory opening-day attendance directly printed; school2026openingSep1 links current Tuesday class clock; remaining normal dates/period unconfirmed', sourcePlanResponseSHA256=plan['sourceResponseSHA256'], datesOrClockInvented=False, partialSchedule=True, derivedOpeningClassDate=['2026-09-01'], sourcePrintedRule='First week live Zoom; opening-day mandatory attendance', derivedDateBasis='Official school2026openingSep1 plus currentTuesday600-720 class; date not independently printed asSep1 in plan', physicalClassroomNotAppliedToOnline=True, periodMeaning='Boundary of directly confirmed first-class meeting only, not normal course period', unconfirmedScheduleParts=['remaining ordinary teaching dates and actual ending', 'actual midterm/final dates', 'any individual makeup schedule'])
old_sentence = '수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
for department, text in c['departmentRemarks'].items():
    text = '\n'.join(line for line in text.splitlines() if line != old_sentence)
    c['departmentRemarks'][department] = text + '\n일반 수업 날짜 확인 중: 지금 반영된 일정은 공개 계획의 개강일 참석 안내와 학사력으로 확인한 9월 1일 실시간 온라인 수업 1회입니다. 나머지 일반 수업·시험·보강 날짜와 실제 수업 종료일은 미확인입니다.'
for previous, current in zip(old['courses'], new['courses']):
    if previous['sourceEducation']['courseId'] != cid:
        assert previous == current
    else:
        for field in ['professor', 'courseName', 'courseCode', 'section', 'classification', 'departmentClassifications', 'credits', 'departmentCredits', 'departments', 'sourceSchedule', 'sourceClassroom']:
            assert previous[field] == current[field]
        assert previous['sourceEducation']['originalEducationFields'] == current['sourceEducation']['originalEducationFields']
        assert previous['sourceEducation']['actualDisplayedClocks'] == current['sourceEducation']['actualDisplayedClocks']
new['verificationScope'] = 'Research next11: previous10 unchanged; mandatory opening-day live teaching via current plan plus schoolopening rule only; remaining ordinary period unconfirmed'
f = R / 'cnu-unknown-2026-2.whole-checkpoint-next-eleven-openinglive-partial.json'
f.write_text(json.dumps(new, ensure_ascii=False, indent=2) + '\n')
proof = {'courseId': cid, 'verifiedOn': '2026-10-08', 'sourcePlanResponseSHA256': plan['sourceResponseSHA256'], 'freshEducationCacheSHA256': hashlib.sha256((R / 'cnu-one-openinglive-current-education-recheck' / f'{cid}.json').read_bytes()).hexdigest(), 'actualPublicTeacher': c['professor'], 'currentYear': 2026, 'actualCourseIdentityChecked': True, 'currentPlanCatalogClockRoomMatch': True, 'normalOpeningDayMandatoryAttendance': True, 'singleMeeting': c['schedules'][0], 'firstDatePrintedYearInterpretation': 'Plan prints opening-day rule, school current2026calendar openingSep1; actualTuesday matches current fixed class clock. Plan does not independently printSep1.', 'clockBasis': 'Directly mandated opening-day live teaching at current fixed Tuesday class clock; physical classroom metadata retained but not copied to online session; no access link stored', 'remainingNormalPeriodConfirmed': False, 'repeatedMeetingsGenerated': False, 'privacyScope': 'Public education only; no contacts/security IDs or access information'}
(R / 'cnu-next-openinglive-rule-proof-20261008.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
audit = {'candidate': f.name, 'candidateSHA256': hashlib.sha256(f.read_bytes()).hexdigest(), 'previousTenCandidateSHA256': hashlib.sha256(source.read_bytes()).hexdigest(), 'previousTenCoursesAnd170MeetingsUnchanged': True, 'originalEducationMetadataPublicTeacherAndRestrictionsUnchanged': True, 'wholeRows': 3888, 'scheduledCourses': 11, 'datedMeetings': 171, 'addedConfirmedMeetings': 1, 'addedPartialCourse': cid, 'wholeSupportClaim': False}
(R / 'cnu-next-eleven-openinglive-partial-candidate-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print('next11 partial research candidate:171 meetings; mandatory openingday live class only')
