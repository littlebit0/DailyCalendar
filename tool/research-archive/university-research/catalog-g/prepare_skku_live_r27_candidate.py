"""Review-only current declared-live planned times; no network or production edits."""
import collections
import copy
import datetime
import hashlib
import importlib.util
import json
from pathlib import Path

P = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('base', P/'prepare_skku_planned_regular_r25_candidate.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def read(name):
    return json.loads((P/name).read_text())


def main():
    review = read('skku-source36-realtime-whole-operating-review.json')
    decisions = {r['offeringCode']: r for r in review['decisions']}
    source = {r['offeringCode']: r for r in read('skku-public-operating-plan-audit.json')['records']}
    source.update({r['offeringCode']: r for r in read('skku-inline-education-repaired-20261008-r26-proof.json')['records']})
    rules = read('skku-current-term-closure-rule-evidence.json')
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    proof = P/'skku-source36-realtime-whole-operating-review-r27-proof.json'
    proof_sha = base.immutable(proof, review)
    manifest = {'universityId': 'skku', 'semester': '2026-2', 'completionClaim': False,
                'actualAttendanceConfirmed': False, 'wholeOperatingAuditFinished': False,
                'preservedR26Scheduled': 1304, 'declaredLiveModeSource': 'Official current SUUP_TYPE_CD36, never inferred from room',
                'proof': {'path': str(proof), 'sha256': proof_sha}, 'campuses': []}
    added = []
    totals = collections.Counter()
    dates_count = 0
    for campus in base.CAMPUSES:
        data = read(f'skku-{campus}-2026-2.partial-audited-20261008-r26.json')
        old = copy.deepcopy(data)
        for c in data['courses']:
            key = c['courseCode']+'-'+c['section']
            d = decisions.get(key)
            if not d or not d['decision'].endswith('DeclaredLivePlannedCandidate'):
                continue
            r = source[key]
            detail = r['detail'][0]
            row = r['sourceRow']
            assert row['SUUP_TYPE_CD'] == '36' and row['HAKBU_JIBJUNG_GB'] == 'N'
            assert r['currentDetailIdentityConfirmed']
            assert detail['PER_NAME'] == row['PER_NAME'] == c['professor']
            assert base.frames(detail['SUUP_YOIL_GYOSI']) == base.frames(row['GYOSI_NAME'])
            assert c['sourceSchedule'] == row['GYOSI_NAME'] == d['exactPublishedClock']
            frames = c['rawMeetingFrameForReviewOnly']
            assert len(frames) == 2 and all(f['classroom'] == '미지정' for f in frames)
            excluded = set(d.get('explicitExcludedRegularDates', []))
            meetings = []
            day = start
            while day <= end:
                if day.isoformat() not in closed | excluded:
                    meetings.extend({**f, 'classroom': '', 'date': day.isoformat(), 'deliveryMode': 'liveOnline'}
                                    for f in frames if f['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            assert meetings and c['scheduleStatus'] != 'scheduled'
            c.update(scheduleStatus='scheduled', schedules=meetings,
                     period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                     unresolvedReasons=[], researchOnly=False, actualAttendanceConfirmed=False,
                     scheduleEvidenceKind='plannedRegularTimetable', commonClosureDatesApplied=True,
                     operatingReviewBasis=d['basis'], explicitExcludedRegularDates=sorted(excluded),
                     sourceEducationalOperatingEvidenceReference={'file': proof.name, 'offeringCode': key},
                     sourceDeclaredDeliveryMode='liveOnline')
            for dep, note in c['departmentRemarks'].items():
                c['departmentRemarks'][dep] = note + '\n학교 공시 실시간 온라인 수업시간에 학기·휴업일과 계획서 개별 대체일을 적용했습니다. 실제 시험·개인 면담·녹화 대체 수업 시간은 별도 공지를 확인하세요.'
            added.append(key)
        for before, after in zip(old['courses'], data['courses']):
            assert before['sourceEducationalMetadata'] == after['sourceEducationalMetadata']
            assert before['sourceSchedule'] == after['sourceSchedule'] and before['professor'] == after['professor']
            if before['scheduleStatus'] == 'scheduled':
                assert before == after
        counts = collections.Counter(c['scheduleStatus'] for c in data['courses'])
        totals.update(counts)
        dates_count += sum(len(c.get('schedules', [])) for c in data['courses'])
        path = P/f'skku-{campus}-2026-2.partial-audited-20261008-r27.json'
        sha = base.immutable(path, data)
        manifest['campuses'].append({'campus': campus, 'path': str(path), 'sha256': sha,
                                    'courseCount': len(data['courses']), 'scheduleCounts': dict(counts)})
    assert len(added) == 7
    manifest.update(counts=dict(totals), datedMeetings=dates_count, newLivePlannedCount=len(added),
                    newLivePlannedCodes=sorted(added), heldLiveCodes=sorted(set(decisions)-set(added)))
    base.immutable(P/'skku-partial-audited-20261008-r27-sha-manifest.json', manifest)
    print({'counts': dict(totals), 'dated': dates_count, 'newLive': added})


if __name__ == '__main__':
    main()
