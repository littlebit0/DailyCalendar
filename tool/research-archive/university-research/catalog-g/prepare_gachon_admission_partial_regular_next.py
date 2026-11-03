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
             'reviewPolicy': '25 exact current ordinary lecture methods. Admission online weeks omitted as unresolved, not no-class. Current assessment replacement or variable1.5/2h timings omitted separately. Actual museum/optional field requirements disclosed; no new event times invented.', 'productionProjectionPermitted':'validated2531PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2506-explicit-date-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2506-explicit-date-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'12705002','15505002','08443001','08443002','08443003','11393005','11670001','13489001','13489002','15733005','05084001','07702001','09571001','11733003','13835001','14088001','14088002','14088003','14088004','15032001','15149002','15149003','K0004001','K0004002','K0004003'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted = [w for w in report['weeklyRows'] if any(t in w['signals'] for t in ['온라인','비대면','대면'])]
            assert omitted and all(any('논술' in t or '입시' in t for t in w['operatingContexts']) for w in omitted)
            extra_assessment = [8] if key[1] in {'11670001','12705002'} else ([8,15] if key[1] in {'15149002','15149003'} else [])
            omitted += [w for w in report['weeklyRows'] if w['week'] in extra_assessment]
            omitted.sort(key=lambda w:w['week'])
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
            weeks = '·'.join(str(w['week']) for w in omitted)
            remarks = {d:r+'\n'+weeks+'주차는 입시 비대면 운영 또는 리포트 대체·시험시간 미확정으로 자동 일정에서 제외했습니다. 이는 휴강 확정이 아닌 부분 공시 계획이며, 해당 주차 운영과 평가·보강은 학교 공지를 확인하세요.' for d,r in remarks.items()}
            if key[1] == '11670001':
                remarks = {d:r+'\n중간고사 대체 과제로 박물관 직접 방문 및 유물 관련 글쓰기가 필요합니다. 방문 시각을 별도로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '15505002':
                remarks = {d:r+'\n모둠 프로젝트 2안은 문학 작품 배경 지역 현지 답사·콘텐츠 제작을 포함합니다. 별도 답사 시각은 미확정입니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'omittedUnresolvedAdmissionOrAssessmentWeeks': omitted, 'semanticRecheck': review['decision'], 'separateExamsMakeupAndFieldDatesNotInvented': True, 'materialsSemanticBasis': 'Normal printed lecture/exploration rules preserved. Admission online operation unresolved weeks and actual report-replacement/variable-duration assessment weeks omitted. Museum or optional field assignments disclosed without invented separate dates.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedAdmissionOrAssessmentWeeks': omitted, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2531-admission-partial-v2-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 25
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2531
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2531-admission-partial-v2-next-audit-20261008.json', audit),
        ('gachon-published-regular-2531-admission-partial-v2-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
