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
             'reviewPolicy': '22 current full weekly published normal plans retain actual no-class, assessment replacement, video-upload and admission exceptions. Explicit makeup time without room retained in student note only, not guessed event. Clinical, personal1:1, placements and actual shortened scopes remain held; unspecified assessment dates not invented.', 'productionProjectionPermitted': 'validated2907PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2885-no-class-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2885-no-class-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets = set('04785001 12705003 13480001 13701004 13763002 13964002 14204001 14296001 14416003 14473002 14478002 14530003 14834001 14894001 15199001 15284002 15351001 15573001 15655001 15882001 15882002 15884001'.split())
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert current_period_weekly_rows_consistent(report, base)
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
            omitted_by_code = {'04785001':[14], '12705003':[7,8], '13480001':[14], '13701004':[4], '13763002':[4,6], '14894001':[9], '15351001':[13], '15573001':[1], '15882001':[1], '15882002':[1], '15884001':[1]}
            omitted = [w for w in report['weeklyRows'] if w['week'] in omitted_by_code.get(key[1],[])]
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            held_dates = {'14296001':['2026-11-30'],'14473002':['2026-12-14'],'15199001':['2026-09-10'],'15655001':['2026-11-30']}.get(key[1],[])
            exact_holiday_live = key[1]=='14478002'
            if exact_holiday_live:
                assert any('10/09' in x and '실시간 화상' in x for w in report['weeklyRows'] if w['week']==6 for x in w['operatingContexts'])
                assert [(b['weekday'],b['startMinute'],b['endMinute']) for b in base['schedules']]==[(5,900,1070)]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and (day.isoformat() not in HOLIDAYS or exact_holiday_live and day.isoformat()=='2026-10-09') and day.isoweekday() != 7 and day.isoformat() not in held_dates and not any(a<=day<=z for a,z in omitted_ranges):
                        meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
                        if exact_holiday_live and day.isoformat()=='2026-10-09':meeting['deliveryMode']='liveOnline'
                        meetings.append(meeting)
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                labels='·'.join(str(w['week']) for w in omitted)
                remarks={d:r+f'\n{labels}주차는 현재 계획의 수업 없음·자료 제출 또는 대면 수업 대신 온라인 강의 업로드로 표시되어 정규 시각 일정에서 제외했습니다. 별도 시험·영상 시각을 만들지 않았습니다.' for d,r in remarks.items()}
            extras={
              '04785001':'현재14주차(12/1~12/7)는 입시 논술고사 휴강 및 보강 추후 공지로 표시됩니다. 해당 주차를 정규 일정에서 제외하고 보강 시각은 만들지 않았습니다.',
              '12705003':'7주차(10/13~10/19)는 학회 참석 휴강,8주차 원중간고사 표기10/24(목)는2026년 요일과 불일치하여 두 주차의 출석 시각은 보류했습니다. 날짜를 임의 교정하거나 보강·시험 이벤트를 생성하지 않았습니다.',
              '13480001':'원12/1계획은 논술고사 현장휴강 대신 온라인 강의입니다.14주차는 방식·시각이 미확정이어서 정규 출석을 생성하지 않았습니다. 온라인 의무는 휴강이 아닌 방식 미확정 범위입니다.',
              '13701004':'추석연휴4주차는 리포트 출석대체입니다. 정규 강의 시각으로 자료 제출 이벤트를 만들지 않았습니다.',
              '13763002':'원4·6주차의 추석·한글날 휴강 안내와 월요일 공시 교시가 일치하지 않아 두 주차를 운영 확인 중 범위로 제외했습니다. 확정 휴강일로 해석하거나 보강 시각을 만들지 않았습니다.',
              '13964002':'9/24휴강 보강은16주차 예정이며 실제 날짜·시각은 미확정입니다. 일반수업 기간 이후 보강 반복이나 확정 시험을 추가하지 않았습니다.',
              '14204001':'9/24목요일휴강 보강은16주차 예정이며 실제 날짜·시각은 미확정입니다. 같은4주차 수요일 정상 공시 교시는 보존하고 별도 보강은 생성하지 않았습니다.',
              '14296001':'10/5·11/30은 영상 강의 대체입니다. 원월요일15:00~16:50에 영상 출석을 확정하지 않았고 영상 시청 의무를 별도 시각 이벤트로 만들지 않았습니다.',
              '14416003':'9/24추석연휴 휴강의 보강 날짜·시각은 미확정입니다. 별도 보강은 학교 공지를 확인하세요.',
              '14473002':'원10/5휴강 보강은12/14기말고사일 당일로 안내됩니다.12/14의 시험·보강 시각 구성은 미확정이어서 원15:00~17:50정규 출석을 보류하고 별도 이벤트를 만들지 않았습니다.',
              '14478002':'원10/9금요일은 실시간 Zoom수업으로 명시되어15:00~17:50공시 계획에 실시간 모드를 보존했습니다.9/25휴강의 보강은12/8~12/13중 개별 발표로 안내되나 정확한 시각·장소 미확정으로 별도 일정은 생성하지 않았습니다.',
              '14530003':'9/24추석 휴강을 제외했습니다. 실습 중 개인 튜토리얼은 공시 강의실 수업의 활동으로 보존하며 별도 개인 지도 시각을 생성하지 않았습니다.',
              '14834001':'9/24추석 휴강의 보강은 예정이며 미확정입니다.12/6프로젝트 보고서·설계파일 제출 마감은 수업 시각이나 추가 출석 일정이 아닙니다.',
              '14894001':'9주차(10/27~11/2)는 중간고사 미실시·휴강으로 명시되어 해당 금요일10/30정규 출석을 제외했습니다.',
              '15199001':'원9/10비엔날레 현장학습은 실제 장소·시각 미확정으로 제외했습니다. 휴일 이후 본문 날짜가 주차 번호와 다르게 진행되므로 원목요일13:00~15:50일반 예약 계획을 사용했습니다.12/17보강은 실제 시각 미확정으로 별도 추가하지 않았습니다.',
              '15284002':'9/24추석휴강의 보강은 기말고사 종료 후 예정입니다. 보강 시각 미확정이므로 일반수업 기간 밖 반복을 만들지 않았습니다.',
              '15351001':'13주차(11/24~11/30)는 대학 입시논술 휴강·추후 보강으로 명시되어 두 정규 수업을 제외했습니다.4주차 오디션 평가는 정규 공시 수업 활동이며 별도 중간고사 이벤트를 만들지 않았습니다.',
              '15573001':'원9/2~9/3담당교수 사정 휴강 및9/24추석 과제대체는 정규 출석에서 제외했습니다. 보강주 수업은 실제 날짜·시각 미확정으로 별도 생성하지 않았습니다.',
              '15655001':'9/25휴강 보강은 전후 예정·미확정입니다.10/5비대면 또는 평가,11/30대면불가 시 비대면 전환은 휴강이 아닌 방식 미확정 범위로 원월09:00~10:50예약 시각에 출석을 확정하지 않았습니다.',
              '15882001':'1주차(9/1~9/7)출장 휴강 및9/25추석휴강의 보강은 협의 예정입니다.10/9한글날 수업 예정도 실제 방식 확정 전이므로 원10:00~11:50시각을 자동 추가하지 않았습니다.',
              '15882002':'1주차(9/1~9/7)출장 휴강 및9/25추석휴강의 보강은 협의 예정입니다.10/9한글날 수업 예정도 실제 방식 확정 전이므로 원15:00~16:50시각을 자동 추가하지 않았습니다.',
              '15884001':'1주차(9/1~9/7)출장 휴강 및9/25추석휴강의 보강은 협의 예정입니다.10/9한글날 수업 예정도 실제 방식 확정 전이므로 원13:00~14:50시각을 자동 추가하지 않았습니다.'
            }
            remarks={d:r+'\n'+extras[key[1]] for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current full weekly plan and school published regular reservation; exact no-class/online replacement/unresolved admission dates omitted.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'individualWeeklyOperationConfirmed': False, 'publishedWeeklyRowCount': len(report['weeklyRows']), 'currentTeachingMethodReviewed': True, 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-09' if exact_holiday_live else None})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-09' if exact_holiday_live else None, 'datedMeetingCount': len(meetings), 'publishedWeeklyRowCount': len(report['weeklyRows']), 'individualWeeklyOperationConfirmed': False,
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2907-no-class-scope-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 22
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2907
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2907-no-class-scope-next-audit-20261008.json', audit),
        ('gachon-published-regular-2907-no-class-scope-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
