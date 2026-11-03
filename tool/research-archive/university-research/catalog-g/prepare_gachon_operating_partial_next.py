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
             'reviewPolicy': '11 current conditional/partial published normal plans. Mere possible future admission Zoom changes do not invent actual date overrides. Translation/report-replacement week8, unconfirmed practical-room weeks, video-including13plus and holiday-week asynchronous scopes omitted exactly. Explicit holiday online branches remain heldDateScopes and visible no-cancellation/unresolved-mode notes. School plans not actual attendance; unknown user-selected source mode preserved.', 'productionProjectionPermitted':'validated2804PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2793-live-weekly-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2793-live-weekly-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'14669001', '61401001', '14286001', 'M0523001', '14629001', '14284001', 'M3757001', 'M3253001', '14629002'}
            targets |= {'15119001','15120001'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            assert not any(w['explicitClockMention'] or w['explicitAdditionalDateMention'] or set(w['signals']) - {'중간고사','기말고사','시험','실습','봉사'} for w in report['weeklyRows'])
            omissions = {'14286001': [8], 'M3253001':[8], '14669001':[5,6,7,8,9,10], 'M0523001':[13,14,15], 'M3757001':[4,5,6]}
            omitted = [w for w in report['weeklyRows'] if w['week'] in omissions.get(key[1], [])]
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and not any(a <= day <= z for a,z in omitted_ranges):
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                labels = '·'.join(str(w['week']) for w in omitted)
                remarks = {d:r+f'\n{labels}주차는 보고서 대체 평가·별도 실습실·영상 포함 수업 또는 휴일 주간의 동영상 운영으로 정규 강의 시각과 실제 운영이 미확정이므로 자동 일정에서 제외했습니다.' for d,r in remarks.items()}
            if key[1] in {'14284001','14286001','61401001','M3253001','14629001','14629002'}:
                remarks = {d:r+'\n입시 또는 학교 운영 상황에 따라 Zoom 수업으로 변경될 수 있습니다. 아직 특정 날짜별 변경이 확정된 것으로 간주하지 않고 현재 정규 공시 계획을 표시합니다.' for d,r in remarks.items()}
            if key[1] in {'14629001','14629002'}:
                remarks = {d:r+'\n수업 전 교재 선행 독해가 필요합니다. 평가는 정규 수업 시간에 예정되어 있고 수업으로 대체될 수도 있어 별도 시험 이벤트를 만들지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '14669001':
                remarks = {d:r+'\n실습 주차의 실제 실습실과 중간 보고서 평가 운영은 별도 확인이 필요합니다. 나머지 현재 이론 강의의 공시 시각만 표시합니다.' for d,r in remarks.items()}
            if key[1] == 'M0523001':
                remarks = {d:r+'\n13주차 이후는 영상 강의를 포함하는 플립러닝으로 안내되어 있어 1–12주 정규 시각만 표시합니다. 휴일 수업의 영상·온라인 운영은 정규 출석 시각으로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == 'M3757001':
                remarks = {d:r+'\n공휴일이 포함된 4·5·6주차는 동영상 수강으로 출석을 인정하므로 해당 주의 정규 수업 시각을 생성하지 않았습니다. 동영상은 그 주 안에 수강해야 합니다. 미확정 16주 보강이나 대체 실시간 시각을 임의 추가하지 않았습니다.' for d,r in remarks.items()}
            held_dates = []
            if key[1] in {'15119001','15120001','M0523001'}:
                for block in base['schedules']:
                    for date in sorted(HOLIDAYS):
                        day = dt.date.fromisoformat(date)
                        if begin <= day <= end and day.isoweekday() == block['weekday']:
                            held_dates.append({'date':date, 'weekday':block['weekday'], 'startMinute':block['startMinute'], 'endMinute':block['endMinute'], 'classroom':block['classroom'], 'sourceMode':'onlineLiveOrVideoUnresolved', 'reason':'Explicit holiday teaching is not cancellation; synchronous/asynchronous allocation not confirmed.', 'sourceTeachingMethod':method})
            if key[1] in {'15119001','15120001'}:
                remarks = {d:r+'\n공휴일과 수업일이 겹치면 Zoom 또는 동영상 수업으로 운영됩니다. 이는 휴강이 아니라 방식 미확정이므로 해당 공휴일의 시각별 자동 일정은 보류했습니다. 그 외 현재 정규 공시 계획만 표시합니다.' for d,r in remarks.items()}
            if held_dates:
                parts = [f"{v['date']} 원공시 {v['startMinute']//60:02}:{v['startMinute']%60:02}–{v['endMinute']//60:02}:{v['endMinute']%60:02}" for v in held_dates]
                detail = '; '.join(parts)
                remarks = {d:r+'\n휴강이 아닌 방식 미확정 보류 범위: '+detail+' (원시각은 공시 계획일 뿐 해당 시각의 실제 수업 확정이나 영상 마감이 아닙니다).' for d,r in remarks.items()}
            if key[1] == 'M3757001':
                remarks = {d:r+'\n영상 운영 보류 범위: 4주차 09/22–09/28, 5주차 09/29–10/05, 6주차 10/06–10/12. 원주차별 시청 의무는 유지되며 시각 이벤트만 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == 'M0523001':
                remarks = {d:r+'\n13–15주차 11/24–12/14의 영상 포함 플립러닝 운영은 시각·방식 미확정으로 자동 시간표에서 보류했습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'heldDateScopes':held_dates, 'heldVideoWeeklyScopes': [w for w in omitted if key[1] == 'M3757001'], 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Current conditional Zoom possibility not definitive date change; individually identified report substitution, practical room,13plus video-including flip and holiday-week video scopes excluded from normal timetable. Generic exams within published frame retained; actual attendance unconfirmed.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'heldDateScopes':held_dates, 'heldVideoWeeklyScopes': [w for w in omitted if key[1] == 'M3757001'], 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2804-operating-partial-v3-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 11
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2804
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2804-operating-partial-v3-next-audit-20261008.json', audit),
        ('gachon-published-regular-2804-operating-partial-v3-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
