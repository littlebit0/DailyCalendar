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
             'reviewPolicy':'Current published regular reservations with current course/section/teacher identity and individually reviewed explicit operating exceptions. Fixed private/ensemble slots are school plans, not confirmed personal allocation/attendance. Exact source dates and modes only; no invented exams or makeup.', 'productionProjectionPermitted': 'validated3041PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-3022-current-art-partial-v2-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-3022-current-art-partial-v2-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            targets=set('05195001 05195002 08280002 08386003 08386006 08386008 08386026 08443004 10698007 11396002 11471002 12830001 13471001 13471002 15290008 15290013 15290016 15290026 15290042'.split())
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            incomplete_live={'08443004','10698007','11396002','15290016','15290026'}
            if key[1] not in incomplete_live:assert current_period_weekly_rows_consistent(report,base)
            else:
                assert all(w['activityPresent'] for w in report['weeklyRows'])
                assert all(1<=w['week']<=15 for w in report['weeklyRows'])
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            if key[1] not in incomplete_live:assert base['schedulingDecision']=='regularCandidate' and not base['blockingReasons']
            assert not report['potentialDifferentTermStatement']
            assert base['period']['kind'] == 'ordinarySemesterFinalExamEnd; conditional makeup is not automatic weekly recurrence'
            assert base['period']['startDate'] == '2026-09-01' and base['period']['endDate'] == '2026-12-14'
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            # These exact reviewed cohorts contain textbook chapters, generic assessments,
            # or first-week safety video as an activity; no weekly slot replacement.
            weekly_contexts = [s for w in report['weeklyRows'] for s in w['operatingContexts']]
            omitted_by_code={'05195001':[13],'05195002':[13],'08386003':[13],'08386006':[14],'08386008':[13],'08386026':[4],'10698007':[8],'11396002':[8,15],'11471002':[14],'13471001':[14]}
            omitted=[w for w in report['weeklyRows'] if w['week'] in omitted_by_code.get(key[1],[])]
            omitted_ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            holiday_conflict=key[1] in {'15290008','15290013','15290042'}
            held_dates=['2026-09-25','2026-10-09'] if holiday_conflict else []
            exact_holiday_live=False
            normal_physical=key[1] in {'05195001','05195002','11471002','13471001','13471002'}
            explicit_normal_dates=None
            blocks=copy.deepcopy(base['schedules'])
            if key[1] in incomplete_live:
                assert not blocks and base['deliveryMode']=='liveOnline'
                groups=[]
                for slot in base['publishedActualSlots']:
                    if groups and slot['weekday']==groups[-1][-1]['weekday'] and slot['period']==groups[-1][-1]['period']+1:groups[-1].append(slot)
                    else:groups.append([slot])
                blocks=[{'weekday':g[0]['weekday'],'startMinute':g[0]['startMinute'],'endMinute':g[-1]['endMinute'],'classroom':base['rawRoom'],'deliveryMode':'liveOnline'} for g in groups]
            assert blocks
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in blocks:
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
                '05195001':'전체 강의실에서 진행하며7주차의 플립러닝도 교실 토론·발표입니다. 첫시간 오리엔테이션은 필참입니다.10/5보강과13주차Zoom보강은 실제 날짜·시각 협의 예정으로 추가하지 않았습니다.',
                '05195002':'전체 강의실에서 진행하며7주차의 플립러닝도 교실 토론·발표입니다. 첫시간 오리엔테이션은 필참입니다.10/5보강과13주차Zoom보강은 실제 날짜·시각 협의 예정으로 추가하지 않았습니다.',
                '08280002':'원월요일·화요일강의는 동일교과이며 두 반의 중간·기말평가가 동시에 시행될 수 있습니다. 실제 시험 시각은 미확정으로 별도 생성하지 않았습니다. 입시 기간의 조건부Zoom수업은 확정 전환이 아니며 일반 정규 예약 계획을 보존했습니다.',
                '08386003':'13주차 강의실이 고사장으로 확정되면 보강 예정이므로 해당 예약 시각은 운영 미확정 범위로 제외했습니다. 나머지 교내 이론2시간·실험2시간 공시 계획과 복수 원강의실은 보존했습니다.',
                '08386006':'14주차의 실험 부분은 Zoom비대면 실시간이라고 명시됩니다. 원4교시 중 이론2시간·실험2시간의 실제 시각 할당이 미확정이므로 전4교시를 실시간으로 강제하지 않고14주차 예약 출석을 보류했습니다.',
                '08386008':'13주차 강의실이 고사장으로 확정되면 보강 예정이므로 해당 예약 시각은 운영 미확정 범위로 제외했습니다. 나머지 교내 이론2시간·실험2시간 공시 계획과 복수 원강의실은 보존했습니다.',
                '08386026':'추석4주차는 온라인 수업 또는 영상 시청으로 명시된 휴강이 아닌 방식 미확정 범위입니다. 조별실험은 교내 실습이며 별도 현장 배정 시각을 만들지 않았습니다.',
                '08443004':'개별 주차별 운영 계획은 현재 공개 자료에 완전히 게시되지 않았습니다. 현재과목·분반·교수·학기와 실시간화상강의 제목 및 정규 수요일09:00~10:50예약에 따른 학교 공시 계획입니다. 마이크는 꺼야 하며4회이상결석은F,중간·기말 중1회는 응시해야 합니다.',
                '10698007':'현재 주차별 공개 계획에서11주차(11/10~11/16)는 게시되지 않았습니다. 미게시는 휴강의 증거가 아니므로 해당 구간도 학교 공시 정규 예약 계획으로 보존하되 실제 운영 전체가 확인됐다는 의미는 아닙니다.8주차 과제대체 평가만 정규 출석에서 제외했습니다.',
                '11396002':'현재 공개 주차는1·2·3·8·10·14·15주차이며4·5·6·7·9·11·12·13주차는 미게시입니다. 미게시는 휴강의 증거가 아니므로 공시 목18:00~18:50예약 계획을 보존하되 개별 주차 전체 운영 확인을 의미하지 않습니다.8·15주차는 수업 없음으로 명시되어 제외하고 기말과제 제출 의무는 보존했습니다.',
                '11471002':'강의영상을 집에서 수업 전 시청한 뒤 강의실에서는 조별 토론·발표를 진행합니다. 영상 시청은 출석에 반영되는 준비 의무로 정규예약 시각에 시청 이벤트를 만들지 않았습니다.14주차 비대면 방식 미확정은 보류했습니다.',
                '12830001':'현재 교내 이론·실습·TBL팀활동의 공시 예약 계획입니다. 상황에 따른 분반 실습 및 TBL의 사이버캠퍼스 퀴즈 대체는 조건부 설명으로 실제 학생군별 시각이 확정됐다는 의미가 아닙니다. 실습복 착용·온라인 실습일지 제출·조별 정리와 퇴실 의무를 보존하며 별도 학생군 일정은 만들지 않았습니다.',
                '13471001':'전체강의실 진행과preclass영상 복습·팀활동의 현장 수업 모드를 보존했습니다. 첫오리엔테이션 필참이며14주차12/1Zoom보강은 실제 시각 협의 예정으로 원예약 출석을 보류했습니다.',
                '13471002':'전체강의실 진행과preclass영상 복습·팀활동의 현장 수업 모드를 보존했습니다. 첫오리엔테이션 필참이며9/24Zoom보강은 실제 날짜·시각 협의 예정으로 별도 추가하지 않았습니다.',
                '15290016':'개별 주차별 운영 계획은 현재 공개 자료에 완전히 게시되지 않았습니다. 현행과목·분반·교수·실시간화상강의 제목과 원수15:00~16:50정규 예약 계획을 보존했습니다. 이론·실습13주와 시험2주의 실제 별도 평가 시각은 미확정이며 추가 시험 이벤트를 생성하지 않았습니다.',
                '15290026':'개별 주차별 운영 계획은 현재 공개 자료에 완전히 게시되지 않았습니다. 현행과목·분반·교수·실시간화상강의 제목과 원금09:00~10:50정규 예약 계획을 보존했습니다. 이론·실습13주와 시험2주의 실제 별도 평가 시각은 미확정이며 추가 시험 이벤트를 생성하지 않았습니다.',
            }
            if holiday_conflict:
                clock='09:00~10:50' if key[1]=='15290008' else '11:00~12:50'
                extras[key[1]]=f'현재15주 계획 및 과목·분반·교수와 Zoom실시간 강의 방식은 대응합니다. 다만 휴일 강의 안내의 예시 날짜·요일 또는1학기 사례가 현재2학기와 일치하지 않아9/25·10/9원금{clock}예약은 휴강이 아닌 운영 확인 중 범위로 보류했습니다. 나머지 정상일의 실시간 공시 계획을 보존했습니다. 휴일 예시를 임의 날짜 교정하지 않았습니다.'
            if key[1] in extras:remarks={d:r+'\n'+extras[key[1]] for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode':'inPersonFromCurrentMethod' if normal_physical else 'liveOnlineFromCurrentTitleAndPlan' if base.get('deliveryMode')=='liveOnline' else 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current full weekly plan and school published regular reservation; exact no-class/online replacement/unresolved admission dates omitted.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'individualWeeklyOperationConfirmed': False, 'publishedWeeklyRowCount': len(report['weeklyRows']), 'incompleteWeeklyPublicPlan':key[1] in incomplete_live, 'currentTeachingMethodReviewed': True, 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-09' if exact_holiday_live else None})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': blocks,
                'period': c['period'], 'omittedUnresolvedAssessmentWeeks':omitted, 'heldDateScope':held_dates, 'explicitHolidayClassDate':'2026-10-09' if exact_holiday_live else None, 'datedMeetingCount': len(meetings), 'publishedWeeklyRowCount': len(report['weeklyRows']), 'incompleteWeeklyPublicPlan':key[1] in incomplete_live, 'individualWeeklyOperationConfirmed': False,
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-3041-published-incomplete-partial-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 19
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 3041
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-3041-published-incomplete-partial-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-3041-published-incomplete-partial-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
