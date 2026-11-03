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
             'reviewPolicy':'Current published regular reservations with current course/section/teacher identity and individually reviewed explicit operating exceptions. Fixed private/ensemble slots are school plans, not confirmed personal allocation/attendance. Exact source dates and modes only; no invented exams or makeup.', 'productionProjectionPermitted': 'validated3022PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2983-field-private-partial-v2-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2983-field-private-partial-v2-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets=set('10269010 10269011 10269012 10275001 10422001 10422002 10422005 10601001 10601002 10898002 11056001 11073001 11227002 11333001 11333002 11333003 11334001 11334002 11350001 11393001 11393002 11396003 11471005 11474001 11676001 11676002 11714002 11723001 11723002 11776002 11934001 11934002 12160002 12160003 12286001 12286002 12401001 12409001 12409002'.split())
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
            omitted_by_code={'10422002':[14],'10601001':[8,14,15],'10601002':[8,14,15],'10898002':[13],'11056001':[5,13],'11073001':[6,13],'11227002':[13],'11334001':[4,13],'11334002':[4,13],'11350001':[8,15],'11393001':[5,13],'11393002':[5,13],'11676001':[13],'11676002':[13],'12409001':[8,14],'12409002':[8,14]}
            omitted=[w for w in report['weeklyRows'] if w['week'] in omitted_by_code.get(key[1],[])]
            omitted_ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            held_dates={'12401001':['2026-11-30']}.get(key[1],[])
            exact_holiday_physical=False
            exact_holiday_live=key[1]=='10275001'
            if exact_holiday_live:
                assert any('비대면 실시간 수업' in x for w in report['weeklyRows'] if w['week']==6 for x in w['operatingContexts'])
                assert [(b['weekday'],b['startMinute'],b['endMinute']) for b in base['schedules']]==[(5,840,1010)]
            normal_physical=key[1] in {'11334001','11334002','11471005','11676001','11676002','12160002'}
            if key[1]=='12286001':
                explicit_normal_dates={'2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-30','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04'}
                assert [(b['weekday'],b['startMinute'],b['endMinute']) for b in base['schedules']]==[(5,540,710)]
            else:explicit_normal_dates=None
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and (day.isoformat() not in HOLIDAYS or exact_holiday_live and day.isoformat()=='2026-10-09') and day.isoweekday() != 7 and day.isoformat() not in held_dates and not any(a<=day<=z for a,z in omitted_ranges) and (explicit_normal_dates is None or day.isoformat() in explicit_normal_dates):
                        meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
                        if normal_physical:meeting['deliveryMode']='inPerson'
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
            for w in omitted:
                a,z=w['startMonthDay'],w['endMonthDay']
                contexts=' / '.join(w['operatingContexts'])
                remarks={d:r+f'\n현재{w["week"]}주차({a}~{z}) 원안내: {contexts}. 이 범위는 휴강 확정뿐 아니라 수업 방식·보강·날짜 오류 미확정 범위를 포함하며 정규 출석을 자동 확정하지 않았습니다.' for d,r in remarks.items()}
            extras={
               '10275001':'원6주차는 비대면 실시간 수업이어서10/9금요일14:00~16:50공시 예약에 실시간 모드를 보존했습니다.9/25추석 수업의 보강12/18은 실제 시각 미확정으로 별도 추가하지 않았습니다.',
               '11056001':'5·13주차 미술관 답사 또는 대체·온라인 강의는 실제 운영 미확정입니다. 글쓰기40~50분은 수업 중 활동 길이로 원월14:00~16:50예약 시각을 변경하지 않았습니다. 선택 외부 전시의 별도 장소·시간은 생성하지 않았습니다.',
               '11073001':'6·13주차는 미술현장 방문 또는 외부인사 초빙 세미나로 실제 장소·시각 미확정입니다. 다른 강의실 발표·토론 계획과 구분했습니다.',
               '11227002':'13주차 전시장 답사는 실제 시각·장소 미확정입니다. 매주 페어와1시간 이상 대화하는 과제는 원수10:00~12:50강의 길이나 별도 출석 시각으로 해석하지 않았습니다.',
               '11333001':'시간·지역 제한 없는 자료조사는 팀·개인 연구 과제이며 공시 정규 강의 시각을 폐지하는 상시 온라인 수업 지시가 아닙니다.',
               '11333002':'시간·지역 제한 없는 자료조사는 팀·개인 연구 과제이며 공시 정규 강의 시각을 폐지하는 상시 온라인 수업 지시가 아닙니다.',
               '11333003':'시간·지역 제한 없는 자료조사는 팀·개인 연구 과제이며 공시 정규 강의 시각을 폐지하는 상시 온라인 수업 지시가 아닙니다.',
               '11334001':'원방법에 본 수업은 대면이라고 명시되어 정상 주차의 대면 모드를 보존했습니다.4·13주차 비대면 또는 비대면 특강은 실제 세부 방식 미확정으로 제외했습니다.',
               '11334002':'원방법에 본 수업은 대면이라고 명시되어 정상 주차의 대면 모드를 보존했습니다.4·13주차 비대면 또는 비대면 특강은 실제 세부 방식 미확정으로 제외했습니다.',
               '11350001':'진로·취업 교과는 재학 중 저학년 진로1과목·고학년 취업1과목만 수강 가능하며 인성·진로세미나는 해당 제한에 포함되지 않는다고 안내됩니다.8·15주차는 자료 제출 평가로 정규 출석을 보류했습니다.',
               '11393001':'개천절 대체 과제와13주차 화상 조별 발표는 실제 시청·발표 방식 미확정으로 정규 출석을 확정하지 않았습니다. 패들렛·멘티미터·폼은 강의 소통 도구이며 상시 영상수업 지시가 아닙니다.',
               '11393002':'개천절 대체 과제와13주차 화상 조별 발표는 실제 시청·발표 방식 미확정으로 정규 출석을 확정하지 않았습니다. 패들렛·멘티미터·폼은 강의 소통 도구이며 상시 영상수업 지시가 아닙니다.',
               '11396003':'G-ted영상·리뷰·토론·참여는 수업 활동이며 정규 시각 전체를 비실시간 시청으로 대체한다는 지시는 관측되지 않았습니다.',
               '11471005':'현재 방법은 대면 이론 강의로 명시되어 대면 모드를 보존했습니다. 수업 중 리뷰·과제 컨설팅은 정상 공시 활동입니다.',
               '11474001':'14주차 동영상 발표는 제작물 발표 활동이며 녹화 강의 수강으로 정규 출석을 대체한다고 해석하지 않았습니다.',
               '11676001':'원비전타워 체육관에서 실기 강의로 진행되어 정상 주차 대면 모드를 보존했습니다.13주차는 비대면 팀과제·영상 제출로 정규 출석을 보류했습니다. 영상 제출은 평가 의무로 별도 시각 이벤트를 만들지 않았습니다.',
               '11676002':'원비전타워 체육관에서 실기 강의로 진행되어 정상 주차 대면 모드를 보존했습니다.13주차는 비대면 팀과제·영상 제출로 정규 출석을 보류했습니다. 영상 제출은 평가 의무로 별도 시각 이벤트를 만들지 않았습니다.',
               '11714002':'1/4~4/4는 작품별 제작 단계 표기로 단축된4주 수업기간이나 실제 시작시각으로 해석하지 않았습니다.',
               '11723001':'자율 대지 답사는 과제 준비이고 해당 주차에는 발제·대지 추첨·전시기획서 및 다음 주 분석 발표를 진행합니다. 매시간 준비물을 갖춘 스튜디오 공시 계획을 보존하며 자율 답사 출석 시각을 생성하지 않았습니다.',
               '11723002':'자율 대지 답사는 과제 준비이고 해당 주차에는 발제·대지 추첨·전시기획서 및 다음 주 분석 발표를 진행합니다. 매시간 준비물을 갖춘 스튜디오 공시 계획을 보존하며 자율 답사 출석 시각을 생성하지 않았습니다.',
               '11776002':'팀별 실내악 곡 협의는 작품 선정이며 개인 강의 시각 재배정 지시는 아닙니다. 팀 앙상블의 학교 공시 예약 시각을 보존했습니다.',
               '11934001':'10/11·11/17·12/1는 전시 감상문·작품사진 제출 마감이며 수업 시각 변경이나 별도 출석을 생성하지 않았습니다.',
               '11934002':'10/11·11/17·12/1는 전시 감상문·작품사진 제출 마감이며 수업 시각 변경이나 별도 출석을 생성하지 않았습니다.',
               '12160002':'현재 수업 방법은 대면 수업으로 명시되어 정규 공시 예약에 해당 모드를 보존했습니다.',
               '12160003':'현재 앙상블 레슨 및15주 주차 계획에 대응하는 고정 공시 예약 시각을 보존했습니다. 별도 시각 협의나 학생별 교대 지시는 관측되지 않았습니다.',
               '12286001':'추석 이후 내용 주차와 본문 날짜가 달라 초기9/4·9/11·9/18과 명시된10/2·10/16·10/30·11/6·11/13·11/20·11/27·12/4의 공시 금09:00~11:50계획만 보존했습니다.10/9온라인 방식,본문에 확정되지 않은10/23·12/11및12/18발표의 별도 시각은 미확정으로 보류했습니다. 원주차를 임의 이동하여 날짜를 만들지 않았습니다.',
               '12286002':'현직 특파원 화상 연결 또는 언론인 초빙은 학생이 강의실에서 참여하는 활동입니다. 전체 강좌를 비대면으로 바꾸거나 해외 현장 방문 시각을 생성하지 않았습니다.',
               '12401001':'11/30온라인 수업은 휴강이 아닌 방식 미확정 범위로 원월15:00~16:50출석을 자동 확정하지 않았습니다.',
               '12409001':'8주차 보고서 제출 및14주차 동영상 강의 예정은 정규 시각의 출석으로 확정하지 않았습니다. 소감 발표1분은 발표 길이이며 수업 길이나 시작시각이 아닙니다.',
               '12409002':'8주차 보고서 제출 및14주차 동영상 강의 예정은 정규 시각의 출석으로 확정하지 않았습니다. 소감 발표1분은 발표 길이이며 수업 길이나 시작시각이 아닙니다.',
            }
            if key[1].startswith('10269'):extras[key[1]]='현재15주 계획과 과목·분반·교수에 대응하는 학교 공시의 개인 실기 정규 예약 시각입니다. 별도 시각 협의·학생별 교대·재배정 지시는 관측되지 않았습니다. 개별 실제 지도 배정 변경은 학교 공지를 확인해야 하며 실제 참석이나 별도 개인 배정 시각을 확정한 것이 아닙니다.'
            if key[1] in extras:remarks={d:r+'\n'+extras[key[1]] for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode':'inPersonFromCurrentMethod' if normal_physical else 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
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
        outname = f'gachon-{campus}-2026-2.published-regular-3022-current-art-partial-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 39
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 3022
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-3022-current-art-partial-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-3022-current-art-partial-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
