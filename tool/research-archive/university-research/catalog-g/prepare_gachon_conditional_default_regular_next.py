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
             'reviewPolicy': 'Four current published default plans. Three have only conditional future need/weather delivery changes and preserve those notices; one uses video illustration with lecture/quizzes/discussion. All current weekly bounds and clocks match, no dated exception declared. No actual attendance or speculative weather-based override.', 'productionProjectionPermitted':'validated2608PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2604-english-partial-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2604-english-partial-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            method = report['teachingMethodEducationalExcerpt']
            if c['scheduleStatus'] != 'unrecognized' or key[1] not in {'07251006','07752001','12274001','12274002'}:
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            weekly_contexts = [t for w in report['weeklyRows'] for t in w['operatingContexts']]
            assert not any(w['explicitClockMention'] or w['explicitAdditionalDateMention'] or set(w['signals']) - {'중간고사','기말고사'} for w in report['weeklyRows'])
            if key[1] == '07251006':
                assert '대면 강의로 진행하는 것을 원칙' in method and '필요 시' in method
            elif key[1].startswith('12274'):
                assert '축구장에서 실기로' in method and '폭우, 폭설' in method
            else:
                assert '강의, 퀴즈, 토론, 동영상 시청' in method
            begin, end = (dt.date.fromisoformat(c['period'][k]) for k in ['startDate', 'endDate'])
            meetings = []
            for block in base['schedules']:
                day = begin
                while day <= end:
                    if day.isoweekday() == block['weekday'] and day.isoformat() not in HOLIDAYS and day.isoweekday() != 7:
                        meetings.append({k: v for k, v in {**block, 'date': day.isoformat()}.items() if k not in ['firstPeriod', 'lastPeriod']})
                    day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(c['departmentRemarks'])
            # Remove only the generated uncertainty sentence, preserving enrollment notes.
            auto = '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks = {d: '\n'.join([*(s for s in r.split('\n') if s != auto), NOTE]) for d, r in prior.items()}
            if key[1] == '07251006':
                remarks = {d:r+'\n현재 계획은 대면 강의를 원칙으로 하며 필요 시 온라인 강의를 혼용합니다. 실제 변경 여부는 강사 공지를 확인하세요.' for d,r in remarks.items()}
            elif key[1].startswith('12274'):
                remarks = {d:r+'\n현재 계획은 축구장 실기입니다. 폭우·폭설 시 이론/비대면 수업으로 대체될 수 있으므로 실제 당일 운영은 강사 공지를 확인하세요. 날씨별 대체 일정을 임의 생성하지 않았습니다.' for d,r in remarks.items()}
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'conditionalFutureChangesAreNotConfirmedAttendance': True, 'materialsSemanticBasis': 'Published default physical lecture or football-field practice with conditional future changes, not a claim of actual attendance. Video illustration mixed with discussion/lecture does not declare whole-slot asynchronous delivery. Actual future online/weather decisions are not invented.'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2608-conditional-default-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 4
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2608
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2608-conditional-default-next-audit-20261008.json', audit),
        ('gachon-published-regular-2608-conditional-default-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
