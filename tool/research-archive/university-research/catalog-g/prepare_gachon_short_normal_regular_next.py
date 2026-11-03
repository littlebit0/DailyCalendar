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
             'reviewPolicy': '45 current normal lecture/lab/preclass plans with exact individual15/12/4week bounds. Three4week projects retain Nov24-Dec21 individual source periods instead of ordinary15week makeup inference; eighteen12week plans endNov23. Media support, simulated patient/doctor roleplay and laboratory groupwork are not patient placement. Generic exams do not create separate dates or cancel regular plans. Conditional future online changes unconfirmed, preparation and assessment constraints preserved.', 'productionProjectionPermitted':'validated2740PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2695-normal-lecture-v2-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2695-normal-lecture-v2-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'60000023', '15465001', '15532001', '61349001', '15582001', '61407001', '61115002', '61070001', '61419001', 'M2566001', '61354001', '15548001', 'M3592001', 'M3389001', '61406001', '61080001', '61081001', '61440001', '15469001', '15743003', 'M3591001', '61074001', 'M3262002', 'M3178001', '61482001', 'M1117001', 'K0122002', 'M2607001', 'K0022005', 'M3262001', '61275002', '61689001', 'M0365001', '60000083', 'K0021004', 'M2728001', 'M3262005', '61328001', '61054001', '61509001', 'M3757006', '61508001', 'M3016001', 'M2577002', '60000020'}
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
            omitted = []
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
            if key[1] in {'15465001','15469001','15532001','61354001','61482001','M3178001','M3757006'}:
                remarks = {d:r+'\n수업 결손·진도·학교 운영 상황에 따라 추가 온라인 보강이나 수업 방식 변경이 있을 수 있습니다. 미확정 추가 보강 시각이나 휴일 대체 일정을 임의 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '61115002':
                remarks = {d:r+'\n2·3·11주차 강의 전에 지정된 영상 선행 학습을 완료해야 합니다.' for d,r in remarks.items()}
            if key[1] == 'M1117001':
                remarks = {d:r+'\n강의 전 KOCW 지정 강의 선행 학습과 주말까지 조별 과제 제출이 필요합니다. 과제 제출·학생 발표 순번은 별도 이벤트로 생성하지 않았습니다. 1/4 결석 시 성적 무효, 주말까지 과제 미제출 시 감점됩니다.' for d,r in remarks.items()}
            if key[1] == 'M3757006':
                remarks = {d:r+'\nGoogle Colab 실습용 Google 계정·이메일·Drive 사전 준비가 필요합니다. 4회 이상 결석·시험 불참·리포트 복사 3회 적발 시 F 처리됩니다.' for d,r in remarks.items()}
            if key[1] in {'M3262001','M3262002','M3262005'}:
                remarks = {d:r+'\n지각 3회는 결석 1회이며 4회 이상 결석하면 성적과 관계없이 F입니다. 중간·기말평가 중 한 번 이상 반드시 응시해야 합니다.' for d,r in remarks.items()}
            if key[1] == 'M2577002':
                remarks = {d:r+'\n지각 3회는 결석 1회이며 4회 초과 결석하면 F입니다. 기말평가는 학교 기말고사 일정에 따르므로 별도 확정 시험 시각을 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '61328001':
                remarks = {d:r+'\n12주 수업에서 4회 이상 결석 시 F, 지각 2회는 결석 1회이며 2회 이상 결석하면 A+ 부여가 불가합니다.' for d,r in remarks.items()}
            if key[1] in {'61508001','61509001'}:
                remarks = {d:r+'\n7·12주차 지필평가는 정규 공시 계획의 범위로 표시하며 별도 시험 시각은 확정하지 않았습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'omittedUnresolvedAssessmentWeeks': omitted, 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'materialsSemanticBasis': 'Normal published theory/classroom/lab/preclass/student presentation or generic flip tags with complete current weekly bounds. Patient/doctor role play and group lab are not external placement. Individual4/12week periods preserved, current generic assessments not fabricated, future conditional online changes left unresolved.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedAssessmentWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2740-short-normal-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 45
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2740
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2740-short-normal-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-2740-short-normal-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
