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
             'reviewPolicy': '38 current full weekly published normal plans retain actual no-class, assessment replacement, video-upload and admission exceptions. Explicit makeup time without room retained in student note only, not guessed event. Clinical, personal1:1, placements and actual shortened scopes remain held; unspecified assessment dates not invented.', 'productionProjectionPermitted': 'validated2945PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2907-no-class-scope-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2907-no-class-scope-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets = set('02987002 03005001 03069001 03236001 03459001 03459002 03593001 03874002 03874003 03982001 05194001 05194002 05194003 05194004 05202001 05202002 05205001 05305001 05306001 05306002 05307001 05308002 05309001 05309002 05309003 05310001 05310002 05310003 05311001 05311002 05315001 05707001 05707002 05944002 06127001 06810004 06810005 06810008'.split())
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
            omitted_by_code={'02987002':[14],'03005001':[4],'03069001':[4],'03236001':[13],'03459001':[4],'03459002':[4],'03874002':[6],'03874003':[6],'05194001':[5,13],'05194002':[5,13],'05194003':[5,13],'05194004':[4],'05202001':[5,13],'05202002':[5,13],'05305001':[4],'05306001':[5,13],'05306002':[14],'05307001':[13],'05308002':[13],'05310001':[5],'05310002':[5],'05310003':[5],'05311001':[14],'05311002':[14],'05315001':[4],'05707001':[14],'05707002':[14],'05944002':[13],'06810005':[13]}
            omitted=[w for w in report['weeklyRows'] if w['week'] in omitted_by_code.get(key[1],[])]
            omitted_ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            held_dates={'03593001':['2026-11-30','2026-12-01'],'03982001':['2026-11-30']}.get(key[1],[])
            exact_holiday_live=False
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and (day.isoformat() not in HOLIDAYS or exact_holiday_live and day.isoformat()=='2026-10-09') and day.isoweekday() != 7 and day.isoformat() not in held_dates and not any(a<=day<=z for a,z in omitted_ranges):
                        meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
                        if key[1] in {'05202001','05202002'}:meeting['deliveryMode']='inPerson'
                        if key[1]=='06127001' and day.isoformat()=='2026-11-30':meeting['deliveryMode']='liveOnline'
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
                '03593001':'원11/30·12/1입시 온라인 수업은 휴강이 아닌 방식 미확정 범위입니다. 원월14:00~15:50·화11:00~11:50에 대면 또는 영상 출석을 확정하지 않았습니다.',
                '03982001':'원11/30비대면 수업은 휴강이 아닌 방식 미확정 범위입니다. 원월13:00~14:50출석 방식은 학교 공지를 확인하세요.',
                '03874002':'원6주차 Chuseok Holiday표기는 현재6주차10/6~10/12와 실제추석9/24~9/26이 일치하지 않습니다. 원계획을 임의 날짜 교정하지 않고6주차 운영 미확정 범위를 제외했습니다.',
                '03874003':'원6주차 Chuseok Holiday표기는 현재6주차10/6~10/12와 실제추석9/24~9/26이 일치하지 않습니다. 원계획을 임의 날짜 교정하지 않고6주차 운영 미확정 범위를 제외했습니다.',
                '05202001':'현재5·13주차는 온라인 수업으로 실제 방식이 미확정입니다. 나머지 모든 주차의 원대면 표시를 보존했습니다.2박3일여행은 팀과제 기획 주제이며 실제 교외 방문일정이 아닙니다.',
                '05202002':'현재5·13주차는 온라인 수업으로 실제 방식이 미확정입니다. 나머지 모든 주차의 원대면 표시를 보존했습니다.2박3일여행은 팀과제 기획 주제이며 실제 교외 방문일정이 아닙니다.',
                '05205001':'평가 안내의 기말고사15또는16주차는 미확정입니다. 공시 정규 계획만 보존하고 별도 시험이나 일반기간 밖16주차 반복을 생성하지 않았습니다.',
                '05306001':'생성형AI는 보조도구이며 사용 여부·범위·도구·목적을 과제에 명시해야 합니다.10/5·논술 기간 Zoom보강은 협의 예정으로 실제 보강 시각을 생성하지 않았습니다.',
                '05306002':'12주차 저녁7시는 언어학습 문장 주제이며 실제 강의 시작시각이 아닙니다.14주차 비대면 총정리는 실제 방식 미확정으로 원예약 출석을 보류했습니다.',
                '05308002':'지금은9시야는 중국어 학습주제이며 원월13:00~14:50강의 시각을 변경하지 않습니다.',
                '05309001':'원주차별 추석·개천절·한글날 메모는 해당 날짜의 학교 휴업 규칙으로 적용하며 주차 전체를 휴강으로 임의 확대하지 않았습니다.',
                '05309002':'원주차별 추석·개천절·한글날 메모는 해당 날짜의 학교 휴업 규칙으로 적용하며 주차 전체를 휴강으로 임의 확대하지 않았습니다.',
                '05309003':'원주차별 추석·개천절·한글날 메모는 해당 날짜의 학교 휴업 규칙으로 적용하며 주차 전체를 휴강으로 임의 확대하지 않았습니다.',
                '06127001':'원11/30월요일11:00~11:50은 논술시험으로 실시간 온라인 강의라고 명시되어 해당 모드를 보존했습니다.10/5실시간온라인 강의는 예정으로 휴강이 아닌 방식 미확정 범위이며 원월11:00~11:50출석을 확정하지 않았습니다.',
                '06810005':'원11/29논술고사 비대면 예정은 정규월·수요일과 날짜가 다릅니다.13주차 실제 방식 미확정 범위를 제외하고 날짜를 임의 교정하지 않았습니다.',
            }
            if key[1] in extras:remarks={d:r+'\n'+extras[key[1]] for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode':'inPersonFromCurrentWeeklyPlan' if key[1] in {'05202001','05202002'} else 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
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
        outname = f'gachon-{campus}-2026-2.published-regular-2945-current-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 38
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2945
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2945-current-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2945-current-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
