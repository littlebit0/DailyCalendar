"""Immutable planned live classes, preserving unresolved assessment and holiday operation."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent

ROOT = Path(__file__).resolve().parent
OFFERS = {'10605001','10605002','14633003','15290007','15290019','15290025','15290030','15290033','15290038','15290039','M3651001','M3756001','M3756002'}

def read(name):
    return json.loads((ROOT / name).read_text())

def main():
    reports = {(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
    bases = {(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
    audit = {'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,
             'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated2441PublishedPlansOnly',
             'previousManifest':'gachon-published-regular-2428-class-materials-next-sha-manifest-20261008.json',
             'excludedNationalHolidays':sorted(HOLIDAYS),'holidayExceptionOfferings':['15290025'],
             'reviewPolicy':'Current direct live-method evidence. Eleven actual mixed/unconfirmed assessments omit weeks8/15; generic exams alone do not cancel two ordinary creative-thinking plans. Current15290025 explicitly teaches on holidays without cancellation. Three incorrect-year/weekday holiday declarations remain held.',
             'datasets':[],'promoted':[]}
    for campus in ['global','medical']:
        data = copy.deepcopy(read(f'gachon-{campus}-2026-2.published-regular-2428-class-materials-next-20261008.json'))
        for c in data['courses']:
            offering = c['courseCode'] + c['section']
            if offering not in OFFERS:
                continue
            key = ('20' if campus == 'global' else '21', offering)
            report, base = reports[key], bases[key]
            assert c['scheduleStatus'] == 'unrecognized'
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            assert current_period_weekly_rows_consistent(report,base)
            method = report['teachingMethodEducationalExcerpt']
            assert '실시간' in method or '온라인 화상수업' in method
            complete = offering in {'14633003','M3651001'}
            omitted = [] if complete else [w for w in report['weeklyRows'] if w['week'] in [8,15]]
            ranges = [(dt.date(2026,*map(int,w['startMonthDay'].split('/'))),dt.date(2026,*map(int,w['endMonthDay'].split('/')))) for w in omitted]
            special_holiday = offering == '15290025'
            if special_holiday:
                assert '휴강없이' in method and 'Zoom 실시간강의' in method
            begin,end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate','endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoweekday() != 7 and (day.isoformat() not in HOLIDAYS or special_holiday) and not any(first <= day <= last for first,last in ranges):
                        meetings.append({**{k:v for k,v in block.items() if k not in ['firstPeriod','lastPeriod']},'date':day.isoformat(),'deliveryMode':'liveOnline'})
                    day += dt.timedelta(days=1)
            assert meetings
            old_remarks = copy.deepcopy(c['departmentRemarks'])
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d:'\n'.join([*(line for line in text.split('\n') if line != auto),NOTE]) for d,text in old_remarks.items()}
            if omitted:
                remarks = {d:text+'\n학교 공시의 일반 수업은 실시간 화상강의입니다. 8·15주차는 대면시험·과제대체·평가방법이나 시각이 미확정이므로 자동 일정에 포함하지 않았습니다. 평가 일정은 학교 공지를 확인하세요.' for d,text in remarks.items()}
            if special_holiday:
                remarks = {d:text+'\n현재 수업계획의 공휴일에도 휴강 없이 Zoom 강의를 진행한다는 지침을 반영했습니다.' for d,text in remarks.items()}
            c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,
                     sourceDepartmentRemarks=old_remarks,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,
                     'sourceDeliveryMode':'publishedPerMeetingOverride','sourceCampusExplicit':key[0],
                     'explicitLiveMethod':method,'omittedUnresolvedAssessmentWeeks':omitted,'specialHolidayInstruction':special_holiday,
                     'dateProof':'Current individual weekly teaching bounds and normal published clock; assessment times not inferred.',
                     'holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13, subject-specific live method exception',
                     'calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','examEventsInvented':False})
            audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'currentTeachingMethod':method,
                'originalClockBlocks':[{**b,'deliveryMode':'liveOnline'} for b in base['schedules']],
                'period':c['period'],'datedMeetingCount':len(meetings),'omittedUnresolvedAssessmentWeeks':omitted,
                'specialHolidayInstruction':special_holiday,'currentAssessmentEvidence':[s for s in report['operatingContexts'] if '중간고사' in s or '기말고사' in s]})
        data['currentFullOperatingAuditFinished'] = False
        filename = f'gachon-{campus}-2026-2.published-regular-2441-live-partial-next-20261008.json'
        path = ROOT / filename
        assert not path.exists()
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        audit['datasets'].append({'file':filename,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'campus':campus,
            'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 13
    audit['scheduledCount'] = sum(r['counts']['scheduled'] for r in audit['datasets'])
    audit['datedMeetingCount'] = sum(r['datedMeetingCount'] for r in audit['datasets'])
    assert audit['scheduledCount'] == 2441
    for name,value in [('gachon-published-regular-2441-live-partial-next-audit-20261008.json',audit),
                       ('gachon-published-regular-2441-live-partial-next-sha-manifest-20261008.json',{k:v for k,v in audit.items() if k != 'promoted'})]:
        path = ROOT / name
        assert not path.exists()
        path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in audit.items() if k not in ['promoted','reviewPolicy']},ensure_ascii=False))

if __name__ == '__main__':
    main()
