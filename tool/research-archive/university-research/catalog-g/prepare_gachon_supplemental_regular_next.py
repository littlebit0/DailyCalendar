"""Re-evaluate reviewed textbook numbering and supplemental teaching materials, without changing published plans."""
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
             'reviewPolicy': 'Reviewed exact subject cohorts: textbook chapter/exercise numbers and historical dates do not change attendance. CyberCampus or Google Classroom notices/uploading, prior e-learning, demonstration videos and regular lab activities are support for normal published slots. Generic exams create no extra event. Explicit no-class, even-week lecture, assessment subgroup, actual clock change and actual field replacement remain held.', 'productionProjectionPermitted': 'validated2141PublishedPlansOnly',
             'previousManifest': 'gachon-published-regular-2015-preclass-next-sha-manifest-20261008.json'}
    for campus in ['global', 'medical']:
        name = f'gachon-{campus}-2026-2.published-regular-2015-preclass-next-20261008.json'
        original = read(name)
        data = copy.deepcopy(original)
        for c in data['courses']:
            key = ('20' if campus == 'global' else '21', c['courseCode'] + c['section'])
            review, report, base = reviews[key], reports[key], bases[key]
            numbered_subjects = {'09131','09392','10996','12544','13107','13482','13989','13990','14309','15172','15380','15953','15999','61684','M3648','M3676'}
            supplemental_subjects = {'13530','15054','16001','M0442','M0191','15293','M0859','M3237','08877','14513','15833','16005','M0357'}
            signals = {s for w in report['weeklyRows'] for s in w['signals']}
            numbered = review['decision'] == 'ordinary-current-operating-markers-need-review' and c['courseCode'] in numbered_subjects and signals <= {'기말고사','중간고사','시험'}
            supplemental = review['decision'] == 'ordinary-teaching-method-hybrid-marker-needs-review' and c['courseCode'] in supplemental_subjects
            if c['scheduleStatus'] != 'unrecognized' or not (numbered or supplemental):
                continue
            assert report['educationalParserVersion'] == 6
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert base['schedulingDecision'] == 'regularCandidate' and not base['blockingReasons']
            result = current_period_weekly_rows_consistent(report, base)
            assert result is True, (key, result)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            # These exact reviewed cohorts contain textbook chapters, generic assessments,
            # or first-week safety video as an activity; no weekly slot replacement.
            weekly_contexts = [s for w in report['weeklyRows'] for s in w['operatingContexts']]
            assert not any(t in s for s in weekly_contexts for t in ['휴강', '대체 수업', '비대면', '논술고사', '온라인 수업'])
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
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                     departmentRemarks=remarks, sourceDepartmentRemarks=prior,
                     sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                         'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceCampusExplicit': key[0],
                         'dateProof': 'Current individual weekly teaching bounds and published regular clock.',
                         'holidayProof': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
                         'calendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
                         'semanticRecheck': review['decision'], 'supplementalVideoCreatesNoExtraCalendarEvents': True, 'falsePositiveResolution': 'Numbering/history is subject content' if numbered else 'Materials, assignment submission and announcements support published regular class'})
            audit['promoted'].append({'sourceId': c['sourceId'], 'offering': key[1], 'campus': campus,
                'previousReason': review['decision'], 'currentTeachingMethod': report['teachingMethodEducationalExcerpt'],
                'weeklyOperatingContexts': weekly_contexts, 'originalClockBlocks': base['schedules'],
                'period': c['period'], 'datedMeetingCount': len(meetings),
                'generatedUncertaintyRemovedOnly': auto, 'sourceEnrollmentEvidence': review['enrollmentReview']})
        data['currentFullOperatingAuditFinished'] = False
        outname = f'gachon-{campus}-2026-2.published-regular-2141-supplemental-next-20261008.json'
        out = ROOT / outname
        assert not out.exists()
        out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': outname, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
            'campus': campus, 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted']) == 126
    audit['scheduledCount'] = sum(d['counts']['scheduled'] for d in audit['datasets'])
    assert audit['scheduledCount'] == 2141
    audit['datedMeetingCount'] = sum(d['datedMeetingCount'] for d in audit['datasets'])
    for filename, content in [('gachon-published-regular-2141-supplemental-next-audit-20261008.json', audit),
        ('gachon-published-regular-2141-supplemental-next-sha-manifest-20261008.json', {k: v for k, v in audit.items() if k != 'promoted'})]:
        out = ROOT / filename
        assert not out.exists()
        out.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k not in ['promoted', 'reviewPolicy']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
