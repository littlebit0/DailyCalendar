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
             'reviewPolicy': '29 current ordinary lecture plans: slides/videos/reading/preclass/lecture-lab and studio livecoding preserve school plans. Actual translation-task assessments omit8/15 in1 offering; biochemistry cybercampus wording is assignment submission channel/deadline, not exam-delivery override. Conditional online holiday makeup creates no invented meeting. Actual participation, prerequisite and assignment penalties preserved. Unknown mode not forced, actual attendance unconfirmed.', 'productionProjectionPermitted':'validated2695PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2666-materials-lab-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2666-materials-lab-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'14788001', '14853001', '14806001', '15420003', '15420005', '14805002', '14216001', '15313001', '12551001', '04049001', '14473003', '08913001', '15381001', '15420004', '14826001', '14101001', '14946002', '08306005', '13538001', '13701005', '13978003', '13216005', '08306004', '15420002', '13979004', '14825001', '14486001', '13456001', '13644001'}
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
            omitted = [w for w in report['weeklyRows'] if key[1] == '14216001' and w['week'] in {8,15}]
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
                remarks = {d:r+'\n8·15주차 평가가 번역 과제 제출로 운영되어 정규 강의 시각의 실제 운영이 미확정이므로 자동 일정에서 제외했습니다.' for d,r in remarks.items()}
            if key[1] == '04049001':
                remarks = {d:r+'\n과제는 사이버캠퍼스를 통해 제출합니다. 과제 마감 시각을 별도 수업이나 시험 일정으로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '14806001':
                remarks = {d:r+'\n공휴일 휴강 시 온라인 보강이 예정되어 있으나 별도 시각이 미확정이므로 임의 보강 일정을 추가하지 않았습니다. 1/4 이상 결석 시 F, 지각 3회는 결석 1회로 처리됩니다.' for d,r in remarks.items()}
            if key[1] in {'08306004','08306005','13978003'}:
                remarks = {d:r+'\n선행 학습 후 수업 중 발표·질의응답에 참여합니다. 결석 4번 이상이면 F 처리됩니다.' for d,r in remarks.items()}
            if key[1] in {'13701005','13979004','14853001'}:
                remarks = {d:r+'\n영상 또는 디지털 교재 사전 학습 후 강의실에서 이론·실습·발표 활동이 진행됩니다.' for d,r in remarks.items()}
            if key[1] == '13644001':
                remarks = {d:r+'\n토질역학·기초공학 선행 지식과 사이버캠퍼스 강의 자료를 사전 학습하고 설계 보고서를 제출해야 합니다.' for d,r in remarks.items()}
            if key[1] == '14486001':
                remarks = {d:r+'\n리딩 발표 참여와 매주 사이버캠퍼스 사전 공지 확인이 필요합니다.' for d,r in remarks.items()}
            if key[1] == '14473003':
                remarks = {d:r+'\n기사 기획·취재·완성 활동이 포함됩니다. 정규 공시 시각 이외의 개별 취재 일시·장소를 임의 추가하지 않았습니다.' for d,r in remarks.items()}
            if key[1] in {'15420002','15420003'}:
                remarks = {d:r+'\n4주 이상 결석 시 F, 지각 3회는 결석 1회로 처리됩니다. 과제 제출 지연 8시간 이상이면 0점 처리됩니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Ordinary published lecture/lecture-lab/preclass/studio livecoding or generic flip tags with normal complete weekly topics; no whole asynchronous allocation asserted. Actual translation-task assessments omitted; biochemistry task submission channel/deadline is not exam modality. Conditional holiday makeup not invented; actual preparation and assessment rules disclosed.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2695-normal-lecture-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 29
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2695
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2695-normal-lecture-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-2695-normal-lecture-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
