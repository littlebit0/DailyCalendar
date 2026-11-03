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
             'reviewPolicy': '38 current full weekly published normal plans retain actual no-class, assessment replacement, video-upload and admission exceptions. Explicit makeup time without room retained in student note only, not guessed event. Actual field/site/date/time conflicts remain individually held. Five current fixed private-lesson reservations have full current15week/code/section/teacher match and no observed time-negotiation or studentrotation instruction; retained as school plans only, not actual personal allocation or attendance. Unspecified assessment dates are not invented.', 'productionProjectionPermitted': 'validated2983PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2945-current-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2945-current-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets=set('06854002 07005001 07005002 07162001 07229001 07229002 07251004 07704001 07726001 07738001 08306002 08392008 08392009 08726001 08834001 08839001 08839002 08856001 08873001 08993001 09074001 09131003 09131008 09131011 09376001 09377001 09392004 09392007 09474001 09623001 09623002 09808001 10130001 10269002 10269003 10269004 10269008 10269009'.split())
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
            omitted_by_code={'07005001':[15],'07005002':[15],'07229001':[10,11,12,13,14,15],'07229002':[11,12],'07251004':[14],'07726001':[4,8],'07738001':[9],'08392008':[14],'08392009':[14],'08726001':[4],'08834001':[5,13],'08873001':[6],'08993001':[15],'09376001':[4],'09377001':[8,14,15],'09392004':[14],'09392007':[14],'09474001':[13],'09623001':[6],'09623002':[6,15],'09808001':[4,6],'10269002':[14],'10269003':[14],'10269004':[14]}
            omitted=[w for w in report['weeklyRows'] if w['week'] in omitted_by_code.get(key[1],[])]
            omitted_ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            held_dates={'08306002':['2026-11-30','2026-12-01'],'09074001':['2026-12-01'],'09131003':['2026-11-30']}.get(key[1],[])
            exact_holiday_live=False
            exact_holiday_physical=key[1]=='10130001'
            if exact_holiday_physical:
                assert any('대체공휴일(대면 수업)' in x for w in report['weeklyRows'] if w['week']==5 for x in w['operatingContexts'])
                assert [(b['weekday'],b['startMinute'],b['endMinute']) for b in base['schedules']]==[(1,600,770)]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and (day.isoformat() not in HOLIDAYS or exact_holiday_physical and day.isoformat()=='2026-10-05') and day.isoweekday() != 7 and day.isoformat() not in held_dates and not any(a<=day<=z for a,z in omitted_ranges):
                        meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
                        if exact_holiday_physical and day.isoformat()=='2026-10-05':meeting['deliveryMode']='inPerson'
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
            for w in omitted:
                a,z=w['startMonthDay'],w['endMonthDay']
                contexts=' / '.join(w['operatingContexts'])
                remarks={d:r+f'\n현재{w["week"]}주차({a}~{z}) 원안내: {contexts}. 이 범위는 휴강 확정뿐 아니라 수업 방식·보강·날짜 오류 미확정 범위를 포함하며 정규 출석을 자동 확정하지 않았습니다.' for d,r in remarks.items()}
            extras={
               '06854002':'9/24추석 연휴의 별도 보강은 실제 날짜·시각 미확정입니다.',
               '07162001':'교재 동영상 사전 시청 뒤 강의실 토론·질문·문제풀이를 진행합니다. 집중열용량계는 열전달 학습주제이며 집중이수 기간이 아닙니다. 사전 영상을 정규 시각의 시청 이벤트로 만들지 않았습니다.',
               '07229001':'중간고사 후 나머지 학기는 매장 현장답사 프로젝트로 명시되어10~15주차 원화16:00~16:50·목13:00~14:50는 정규 출석으로 생성하지 않았습니다.9/22화요일 정상수업 표시를 보존했습니다.',
               '07229002':'11·12주차 현장답사는 실제 장소·시각 미확정입니다. 다른 공시 정규 계획과 구분하며 견학 일정은 생성하지 않았습니다.',
               '07251004':'숫자0.1~10.5는 통신 교재 장·절 번호이며 강의 시작시각이 아닙니다.14주차 논술 비대면은 휴강이 아닌 방식 미확정 범위입니다.',
               '07704001':'9/24·10/5학교휴업의 보강 계획은 실제 보강 날짜·시각이 미확정입니다. 건축물 사례조사 과제는 별도 현장 출석 시각으로 만들지 않았습니다.',
               '08306002':'원10/5·11/30·12/1은 온라인 수업입니다. 이는 휴강이 아닌 방식 미확정 범위로 원월13:00~14:50·화13:00~13:50에 출석 방식을 확정하지 않았습니다.',
               '08392008':'실험실에서 현장 실습은 교내 실험수업입니다.14주차 입시 비대면은 실제 방식 미확정입니다. 원표 복수 강의실을 그대로 보존했습니다.',
               '08392009':'실험실에서 현장 실습은 교내 실험수업입니다.14주차 입시 비대면은 실제 방식 미확정입니다. 원표 복수 강의실을 그대로 보존했습니다.',
               '08834001':'5·13주차는 실시간 비대면 또는 비실시간 녹화영상으로 명시된 휴강이 아닌 방식 미확정 범위입니다. 원월14:00~17:50에 영상 출석을 확정하지 않았습니다.',
               '08839001':'현장 전문가를 강의에 초빙하여 질의응답을 진행합니다. 수강생의 실제 교외 방문이나 별도 시각으로 해석하지 않았습니다.',
               '08839002':'현장 전문가를 강의에 초빙하여 질의응답을 진행합니다. 수강생의 실제 교외 방문이나 별도 시각으로 해석하지 않았습니다.',
               '08856001':'기관 신입생 모집·입학 안내회는 운영계획 수립 프로젝트이며 실제 배정된 현장 근무 시각이 아닙니다. 원10/5추석연휴 표기는 실제 개천절 대체휴일과 이름이 다르며 날짜의 학교 휴업 규칙만 적용했습니다.',
               '08993001':'원COVID19거리두기 유지 시 Webex수업은 조건부 설명이며 실제 전면 온라인 확정을 의미하지 않습니다.15주차 보강기간은 실제 운영 시각 미확정으로 제외했습니다.',
               '09074001':'원12/1화요일은 입시 비대면 예정으로 실제 방식 미확정입니다. 원10:00~11:50출석을 확정하지 않고 같은14주차 수요일 정상 공시 구간은 보존했습니다.',
               '09131003':'10/5는 원안내의 한글날대체휴일 명칭과 달리 실제 개천절 대체휴일입니다.16주차 보강은 실제 시각 미확정입니다.11/30비대면은 휴강이 아닌 방식 미확정 범위로 원월09:00~12:50출석을 확정하지 않았습니다. 최종 동영상 시연은 프로젝트 발표 활동이며 영상수업 대체가 아닙니다.',
               '09131008':'10/5프로젝트 계획 발표 보강은 실제 날짜·시각 미확정입니다. 다른 정상 공시 수업 및 발표·평가회 계획과 구분했습니다.',
               '09131011':'9/25·10/9의 보강은 실제 날짜·시각 미확정입니다. 최종 동영상 시연은 발표 활동으로 영상수업 대체가 아닙니다.',
               '09377001':'중간·기말은 사이버캠퍼스 비대면 평가입니다.14주차 영상 제작·동료 영상 리뷰는 실제 수업 시각 내 활동 또는 과제인지 미확정하여 해당 원화11:00~12:50정규 출석을 보류했습니다. 영상 길이5분을 수업 길이로 해석하지 않았습니다.',
               '09623001':'6주차 안전체험관 개인·단체 견학 일정은 시설 일정에 따라 조정되어 실제 시각 미확정입니다.14일 기말 안내는 원월요일12/14예약 계획과 일치하나 별도 시험 시각을 생성하지 않았습니다. 응급처치 특강은 필수 참여입니다.',
               '09623002':'6주차 안전체험관 견학은 실제 일정 미확정입니다. 원15주차14일 기말 안내는 월요일12/14여서 원화요일12/8예약 시각과 일치하지 않아15주차 출석을 보류했습니다. 별도 시험 시각을 생성하지 않았습니다. 응급처치 특강은 필수 참여입니다.',
               '10130001':'현재5주차의 대체공휴일 대면 수업 표시를 확인하여10/5월요일10:00~12:50학교 공시 계획에 대면 모드를 보존했습니다. 실제 참석 기록이나 별도 시험 시각의 확정은 아닙니다.',
            }
            if key[1].startswith('10269'):
                extras[key[1]]='현재15주 계획과 과목·분반·교수에 대응하는 학교 공시의 개인 실기 정규 예약 시각입니다. 별도 시각 협의·학생별 교대·재배정 지시는 관측되지 않았습니다. 개별 실제 지도 배정의 변경 가능성은 학교 공지를 확인해야 하며 실제 참석이나 별도 개인 배정 시각이 확인됐다고 주장하지 않습니다.'
            if key[1] in extras:remarks={d:r+'\n'+extras[key[1]] for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode':'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current full weekly plan and school published regular reservation; exact no-class/online replacement/unresolved admission dates omitted.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'individualWeeklyOperationConfirmed': False, 'publishedWeeklyRowCount': len(report['weeklyRows']), 'currentTeachingMethodReviewed': True, 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-05' if exact_holiday_physical else None})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-05' if exact_holiday_physical else None, 'datedMeetingCount': len(meetings), 'publishedWeeklyRowCount': len(report['weeklyRows']), 'individualWeeklyOperationConfirmed': False,
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2983-field-private-partial-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 38
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2983
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2983-field-private-partial-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-2983-field-private-partial-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
