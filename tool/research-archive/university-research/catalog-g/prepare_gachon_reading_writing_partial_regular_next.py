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
             'reviewPolicy': '53 current reading/writing plans. Reading-trip reports and online-relationship texts are learning topics. Explicit admission-period online writing weeks are individually omitted unless live is stated; three bare admission captions remain held. No attendance claim or generic source mode invented.', 'productionProjectionPermitted':'validated2494PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2441-live-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2441-live-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            if c['scheduleStatus'] != 'unrecognized' or c['courseCode'] not in {'15728','15729','15979'}:
                continue
            if key[1] in {'15979015','15979038','15979045'}:
                continue  # Bare admission-exam caption lacks an actual delivery instruction.
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            omitted = []
            live_weeks = []
            if c['courseCode'] == '15728':
                assert any('보고문 읽기' in t and '답사' in t for t in report['operatingContexts'])
            elif c['courseCode'] == '15729':
                assert any('온라인상에서의 대인관계' in t for t in report['operatingContexts'])
            else:
                for w in report['weeklyRows']:
                    if any(k in w['signals'] for k in ['비대면','온라인']):
                        if '실시간' in w['signals']:
                            live_weeks.append(w)
                        else:
                            omitted.append(w)
                assert omitted or live_weeks
            def bounds(w):
                return tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay'])
            omitted_ranges = [bounds(w) for w in omitted]
            live_ranges = [bounds(w) for w in live_weeks]
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7 and not any(a <= day <= z for a,z in omitted_ranges):
                        meeting = {k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']}
                        if any(a <= day <= z for a,z in live_ranges):
                            meeting['deliveryMode'] = 'liveOnline'
                        meetings.append(meeting)
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if omitted:
                weeks = '·'.join(str(w['week']) for w in omitted)
                remarks = {d:r+'\n'+weeks+'주차는 입시로 인한 비대면/온라인 수업의 실시간 여부가 미확정이므로 자동 일정에서 제외했습니다. 학교 공지를 확인하세요.' for d,r in remarks.items()}
            if live_weeks:
                remarks = {d:r+'\n14주차는 현재 계획서의 명시 실시간 비대면 지침을 반영했습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'omittedUnresolvedOnlineWeeks': omitted, 'explicitLiveWeeks': live_weeks, 'semanticRecheck': review['decision'], 'readingTopicsDoNotCreateFieldTripsOrOnlineDelivery': True, 'materialsSemanticBasis': 'Reading reports about field trips or online relationships is a learning topic, not a trip/online delivery instruction. Writing actual online exceptions are omitted unless live is explicit.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'omittedUnresolvedOnlineWeeks': omitted, 'explicitLiveWeeks': live_weeks, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2494-reading-writing-partial-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 53
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2494
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2494-reading-writing-partial-next-audit-20261008.json', audit),
        ('gachon-published-regular-2494-reading-writing-partial-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
