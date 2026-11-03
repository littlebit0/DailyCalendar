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
    fresh = read('gachon-career139-current-weekly-education-recheck-next-20261008.json')
    assert not fresh['stopped'] and len(fresh['rows']) == fresh['expectedCount'] == 139
    education = {(r['campus'], r['offering']):r for r in fresh['rows']}
    audit = {'completionClaim': False, 'productionRegistered': False,
             'currentFullCollectionComplete': True, 'currentFullOperatingApprovalComplete': False,
             'excludedNationalHolidays': sorted(HOLIDAYS), 'datasets': [], 'promoted': [],
             'reviewPolicy': '139 current career seminar offering weekly activities individually rechecked. Published normal weekly teaching only; weeks4 and10 are unconfirmed timing of mandatory external programme/counselling, omitted as unresolved operation, not claimed no-class. No programme, consultation, assignment, exam or makeup time is invented. Source requirements and partial coverage appear in remarks.', 'productionProjectionPermitted':'validated2331PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2192-school-plan-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2192-school-plan-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            if c['scheduleStatus'] != 'unrecognized' or key not in education:
                continue
            plan = education[key]
            assert [w['week'] for w in plan['weeklyEducationRows']] == list(range(1,16))
            assert all(w['educationalActivity'] for w in plan['weeklyEducationRows'])
            fourth = plan['weeklyEducationRows'][3]
            tenth = plan['weeklyEducationRows'][9]
            assert '취업프로그램' in fourth['educationalActivity'] and '참여' in fourth['educationalActivity']
            assert '1:1상담' in tenth['educationalActivity'].replace(' ','') and 'IAP' in tenth['educationalActivity']
            omitted = [fourth, tenth]
            omitted_dates = {(w['startMonthDay'],w['endMonthDay']) for w in omitted}
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
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
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and not any(dt.date(2026,*map(int,start.split('/'))) <= day <= dt.date(2026,*map(int,end.split('/'))) for start,end in omitted_dates):
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            activity_note = '공시 시간 중 4·10주차는 취업 프로그램·상담의 실제 참여 일정이 확인되지 않아 자동 일정에 포함하지 않았습니다. 학기 중 취업 프로그램 2개 참여, 전문 컨설턴트 1:1 상담 및 IAP 제출 필요. 학교 계획서의 핵심과제 1·2 미이행 시 최소 D학점 부여 안내를 확인하세요. 계약학과·외국인 수강생의 핵심과제 사이버캠퍼스 대체 이수는 학교 안내를 확인하세요.'
            remarks = {d: r + '\n' + activity_note for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'omittedUnresolvedOperationWeeks': omitted, 'individualActivityDatesInvented': False, 'partialPublishedPlan': True})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings), 'omittedUnresolvedOperationWeeks': omitted, 'currentWeeklyEducation': plan['weeklyEducationRows'],
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2331-career-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 139
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2331
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2331-career-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2331-career-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
