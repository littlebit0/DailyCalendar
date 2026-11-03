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
             'reviewPolicy': '38 current theory/classroom/lab/media-support plans. Direct preclass followed by classroom, media illustration and Q&A channels distinguished from whole online delivery. Two report-replacement8th weeks omitted. Four conditional holiday changes disclosed without invented overrides or16week makeup. Mandatory account/preparation/labclothes preserved. No actual attendance or source mode invented.', 'productionProjectionPermitted':'validated2666PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2628-school-plan-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2628-school-plan-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'15981001','15981002','61431004','61431005','M3262003','M3262004','M3393001','M3393002','M3393003','M3393004','M3393005','M3393006','M3265001','M3265002','M3464001','M3464002','M3467001','M3467002','08392006','08392011','12705004','15513001','15536001','15950001','11670003','13837001','14308001','14308013','15291002','15291013','15291014','15291033','15292001','15292002','15732018','15736018','16019001','60016001'}
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
            if key[1] == '15736018':
                assert any('중심 내용 파악하기' in t and '봉사 학점' in t for t in report['operatingContexts'])
            omitted = [w for w in report['weeklyRows'] if key[1] in {'15981001','15981002'} and w['week'] == 8]
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
                remarks = {d:r+'\n8주차는 중간고사 과제 대체로 정규 강의 운영이 미확정이므로 자동 일정에서 제외했습니다.' for d,r in remarks.items()}
            if key[1] in {'15291002','15291013','15291014','15291033'}:
                remarks = {d:r+'\n공휴일 휴강 시 별도 보강 또는 온라인 실시간 수업으로 변경될 수 있습니다. 현재 미확정 보강 시각이나 공휴일 대체 일정을 임의 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] in {'15291013','15291014'}:
                remarks = {d:r+'\nGoogle Colab 실습에 사용할 Google 계정과 이메일·Drive 사전 준비가 필요합니다.' for d,r in remarks.items()}
            if key[1] in {'M3467001','M3467002'}:
                remarks = {d:r+'\n수업은 사전 영상 설명 후 Lab demo·조별 실습으로 진행됩니다. 편한 실습복장이 필요합니다.' for d,r in remarks.items()}
            if key[1] == '15513001':
                remarks = {d:r+'\n문학 영어 원문 사전 독해 및 영상 자료 사전 시청이 필요합니다. 수업 중에는 핵심 장면을 짧게 상영하며 비교·토론합니다.' for d,r in remarks.items()}
            if key[1] == '13837001':
                remarks = {d:r+'\n사이버캠퍼스 수업 자료를 반드시 선행 학습하고 수업에 참여해야 합니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Actual theory plus classroom/lab instruction, direct advance preparation followed by attendance discussion/lab, video/reading illustration or Q&A channels. No whole asynchronous video allocation asserted. Conditional holiday changes remain unresolved; separate actual mandatory preparation disclosed.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2666-materials-lab-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 38
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2666
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2666-materials-lab-next-audit-20261008.json', audit),
        ('gachon-published-regular-2666-materials-lab-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
