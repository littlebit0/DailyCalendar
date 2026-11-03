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
             'reviewPolicy': '12 current planned ordinary offerings. Exact named no-class/video-substitution dates excluded; two holiday-only week5 scopes omitted as unresolved. Generic exams and classroom media/guest topics preserved without invented separate exams, makeup or field schedules.', 'productionProjectionPermitted':'validated2506PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2494-reading-writing-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2494-reading-writing-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            targets = {'06127003','06127004','10217001','13839001','13839002','07135001','61402001','61421001','61389001','03874001','03874004','13723001'}
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in targets:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted = [w for w in report['weeklyRows'] if key[1] in {'03874001','03874004'} and w['week'] == 5]
            exact_closed = {'10217001':['2026-12-01'],'13839001':['2026-12-02'],'13839002':['2026-12-02'],'13723001':['2026-09-04','2026-10-23','2026-11-27']}.get(key[1],[])
            if key[1] in {'06127003','06127004'}:
                assert any('온라인 공간의 미디어 윤리' in t for t in report['operatingContexts'])
            if key[1] in {'13839001','13839002'}:
                assert any('온라인 수업 아님' in t for t in report['operatingContexts'])
                assert any('12/2' in t and '휴강' in t for t in weekly_contexts)
            if key[1] == '13723001':
                assert all(any(day in t and 'No Class' in t for t in weekly_contexts) for day in ['9.4','10.23','11.27'])
            omitted_ranges = [tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and day.isoformat() not in exact_closed and not any(a <= day <= z for a,z in omitted_ranges):
                        meeting = {k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']}
                        meetings.append(meeting)
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                remarks = {d:r+'\n5주차는 수업계획에 휴일명만 기재되어 일반 강의 운영을 확정하지 못했으므로 해당 주차의 자동 일정을 제외했습니다.' for d,r in remarks.items()}
            if exact_closed:
                remarks = {d:r+'\n현재 수업계획의 휴강/영상대체 지침에 따라 '+', '.join(exact_closed)+' 정규 시간 일정을 제외했습니다. 대체 영상·과제·보강 일정을 별도로 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '13723001':
                remarks = {d:r+'\n10/16 보강 예정이라는 지침의 별도 보강 시각은 미확정입니다. 공개 정규 시간 외 추가 일정을 생성하지 않았습니다.' for d,r in remarks.items()}
            if key[1] == '61421001':
                remarks = {d:r+'\n12주차 개인 사례조사보고서에 가능한 대상지 답사가 포함될 수 있습니다. 별도 답사 시각은 생성하지 않았습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'omittedUnresolvedHolidayWeeks': omitted, 'explicitClosedDates': exact_closed, 'semanticRecheck': review['decision'], 'genericExamsDoNotCreateNewEvents': True, 'materialsSemanticBasis': 'Online media ethics is a learning topic; film explicitly not online teaching, guest expert and illustrative videos do not replace normal printed plans. Actual no-class dates and ambiguous holiday-only weeks omitted. Separate assessment/makeup/field timings not invented.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedHolidayWeeks': omitted, 'explicitClosedDates': exact_closed, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2506-explicit-date-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 12
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2506
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2506-explicit-date-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2506-explicit-date-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
