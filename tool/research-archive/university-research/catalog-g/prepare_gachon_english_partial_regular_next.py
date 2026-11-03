"""Re-evaluate previously reviewed supplemental preclass activity, without changing published plans."""
import collections
import copy
import datetime as dt
import hashlib
import json
import re
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
             'reviewPolicy': '73 exact current complete-week English plans, preserving normal classroom language topics. Only actual no-class/makeup/online/TBA/individual assessment operation omitted. Generic group presentation/exams remain planned frames without claiming attendance or separate exam times. Six incomplete current scopes remain held.', 'productionProjectionPermitted':'validated2604PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2531-admission-partial-v2-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2531-admission-partial-v2-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            if c['scheduleStatus'] != 'unrecognized' or c['courseCode'] != '13530':
                continue
            if not current_period_weekly_rows_consistent(report, base):
                continue  # Six incomplete current weekly scopes require a separate school-plan review.
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted = []
            allowed = {'시험','추석','휴강','휴일','보강','온라인','ZOOM','영문날짜표현'}
            for w in report['weeklyRows']:
                assert not set(w['signals']) - allowed
                text = ' '.join(w['operatingContexts'])
                actual_exception = (
                    '휴강' in w['signals'] or '보강' in w['signals'] or
                    bool(re.search(r'ZOOM|on.line review class|online class|online.*make.up|quiz.*online|1/2 students|1/4|remaining students|1:1|10.minute|conducted in pairs|cyber campus exam|to be announced',text,re.I)))
                if actual_exception:
                    omitted.append(w)
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and not any(a <= day <= z for a,z in omitted_ranges):
                        meeting = {k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']}
                        meetings.append(meeting)
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                weeks = '·'.join(str(w['week']) for w in omitted)
                remarks = {d:r+'\n'+weeks+'주차는 원계획의 휴강·보강 미정·온라인평가·입시 비대면·특정 학생군/개별시험 중 일반 시간 운영 미확정 범위를 자동 일정에서 제외했습니다. 별도 시험·영상·보강 시각은 생성하지 않았습니다.' for d,r in remarks.items()}
            assessment = [t for t in report['operatingContexts'] if ('fail' in t.lower() or "'F'" in t or '‘F’' in t) and ('exam' in t.lower() or 'test' in t.lower())]
            if assessment:
                remarks = {d:r+'\n현재 계획서에 필수 시험 미참여 시 F학점 처리 규칙이 있습니다. 시험 운영과 시각은 강사 공지를 확인하세요.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'omittedUnresolvedEnglishOperationWeeks': omitted, 'semanticRecheck': review['decision'], 'textbookOnlineAndHolidayTopicsDoNotChangeDelivery': True, 'materialsSemanticBasis': 'Shopping Online and hypothetical Holiday plans are language-learning topics. Generic presentations/exams do not change the regular planned frame. Actual NoClass, unknown makeup/online operation, individual timed/fractional assessment and TBA scopes omitted. No separate assessment times invented.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedEnglishOperationWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'currentMandatoryAssessmentEvidence': assessment, 'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2604-english-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 73
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2604
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2604-english-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2604-english-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
