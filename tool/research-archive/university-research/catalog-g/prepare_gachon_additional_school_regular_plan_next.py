"""Re-evaluate previously reviewed supplemental preclass activity, without changing published plans."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent

ROOT = Path(__file__).resolve().parent

def read(name):
    return json.loads((ROOT / name).read_text())

def main():
    reports = {(r['campus'], r['sourceRow']['HAKSU_NO']): r for r in read('gachon-full-operating-report-audit.json')['reports']}
    reviews = {(r['campus'], r['officialOfferingCode']): r for r in read('gachon-full-operating-semantic-review.json')['rows']}
    bases = {(c['campusSourceCode'], c['officialOfferingCode']): c for c in read('gachon-full-normalized-source-candidates.json')['courses']}
    audit = {'completionClaim': False, 'productionRegistered': False,
             'currentFullCollectionComplete': True, 'currentFullOperatingApprovalComplete': False,
             'excludedNationalHolidays': sorted(HOLIDAYS), 'datasets': [], 'promoted': [],
             'reviewPolicy': '20 current ordinary theory/discussion/classroom/collective-masterclass plans have zero or one weekly row but current code/teacher/title and normal declared educational methods. Full-period published school planning, not individual weekly operation. Clinical, personal1:1, placements and actual shortened scopes remain held; unspecified assessment dates not invented.', 'productionProjectionPermitted': 'validated2628PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2608-conditional-default-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2608-conditional-default-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets = {'13535004','13535005','13535006','14627002','14627003','14627004','08821001','08821002','08821003','06381001','08817001','14519001','15168001','K0028002','13530006','13530008','13530030','13530037','13530052','13530065'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert len(report['weeklyRows']) <= 1
            if report['weeklyRows']:
                w = report['weeklyRows'][0]
                assert w['week'] == 1 and w['startMonthDay'] == '09/01' and w['endMonthDay'] == '09/07' and not w['signals']
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            assert not report['potentialDifferentTermStatement']
            assert base['period']['kind'] == 'ordinarySemesterFinalExamEnd; conditional makeup is not automatic weekly recurrence'
            assert base['period']['startDate'] == '2026-09-01' and base['period']['endDate'] == '2026-12-14'
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            # These exact reviewed cohorts contain textbook chapters, generic assessments,
            # or first-week safety video as an activity; no weekly slot replacement.
            weekly_contexts = [s for w in report['weeklyRows'] for s in w['operatingContexts']]
            assert not any(t in s for s in weekly_contexts for t in ['휴강', '대체 수업', '비대면', '논술고사', '온라인 수업'])
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7:
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            remarks = {d:r+'\n개별 주차별 운영 계획은 현재 공개 자료에 완전히 게시되지 않았습니다. 학교가 공시한 정규 요일·시간·강의실 및 일반 학기 기간을 사용한 계획입니다.' for d,r in remarks.items()}
            if key[1] == 'K0028002':
                remarks = {d:r+'\n현재 수업계획은 이론60분·토론60분·요약퀴즈30분으로 구성됩니다. 휴식이 포함된 원표의3교시 예약 구간을 보존했습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current regular published timetable, current normal teaching method, school official ordinary semester Sep1-Dec14. Individual weekly table not fully published; no attendance or week-by-week operation confirmation.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'individualWeeklyOperationConfirmed': False, 'publishedWeeklyRowCount': len(report['weeklyRows']), 'currentTeachingMethodReviewed': True})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings), 'publishedWeeklyRowCount': len(report['weeklyRows']), 'individualWeeklyOperationConfirmed': False,
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2628-school-plan-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 20
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2628
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2628-school-plan-next-audit-20261008.json', audit),
        ('gachon-published-regular-2628-school-plan-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
