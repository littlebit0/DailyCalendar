# coding: utf-8
"""Immutable, education-only BU ordinary meetings; unresolved exceptions retained."""
import copy
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent


def read(name):
    return json.loads((ROOT / name).read_text())


def digest(name):
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def prepare():
    old_name = 'bu-dated-normalized-review-unregistered.json'
    old_sha = digest(old_name)
    source_name = 'bu-current-whole-candidate-unregistered.json'
    source = read(source_name)
    originals = {row['courseCode'] + row['section']: row for row in source['courses']}
    previous = read(old_name)
    previous_by_identity = {row['courseCode'] + row['section']: row
                            for row in previous['courses']}
    result = copy.deepcopy(previous)
    omitted_exam = 0
    unknown_delivery = []
    educational_metadata_changes = []
    for row in result['courses']:
        key = row['courseCode'] + row['section']
        raw = originals[key]
        source_notes = ' / '.join(dict.fromkeys(raw['departmentRemarks'].values()))
        # Explicit simultaneous online/offline operation does not establish each
        # learner's attendance venue. A printed classroom alone is insufficient.
        if 'HY-LIVE' in source_notes:
            row['scheduleStatus'] = 'unrecognized'
            row['schedules'] = []
            unknown_delivery.append(key)
        elif row['scheduleStatus'] == 'scheduled':
            meetings = []
            for meeting in row['schedules']:
                if meeting['date'] >= '2026-12-15':
                    omitted_exam += 1
                    continue
                actual = copy.deepcopy(meeting)
                actual['endMinute'] = actual.pop('originalEndMinute')
                meetings.append(actual)
            row['schedules'] = meetings
            assert meetings
            row['period'] = {'startDate': '2026-09-01', 'endDate': '2026-12-14'}
        elif row['scheduleStatus'] == 'untimed':
            row['scheduleStatus'] = 'unscheduled'
        notes = [source_notes] if source_notes else []
        if raw['sourceSchedule'].replace(' ', '') in {'사', '사이버'}:
            notes.append('원 시간표는 사이버 표기이며 고정 출석 시각을 생성하지 않음; 시험 날짜·시각은 별도 공지 확인 필요')
        elif row['scheduleStatus'] == 'unscheduled':
            notes.append('원 시간표에 고정 출석 시각 미게시; 수업 없음으로 단정하지 않음')
        if row['scheduleStatus'] == 'scheduled':
            notes.append('확인된 일반 수업·지정보강 회의만 표시; 12월 15~21일 기말고사 날짜·시각·강의실은 별도 공지 확인 필요')
            if '사' in raw['sourceSchedule']:
                notes.append('사이버 구성은 고정 출석 회의로 생성하지 않음')
            if raw['sourceClassroom'].strip() == '별도':
                notes.append('원 강의실은 별도 표기; 원 비고의 장소와 후속 공지 확인 필요')
        elif row['scheduleStatus'] == 'unrecognized':
            if key in unknown_delivery:
                notes.append('HY-LIVE 온라인·오프라인 홀로그램 수업의 실제 출석 방식·위치 개별 확인 필요')
            else:
                # Keep existing exact unresolved identity/period/field notes.
                prior = previous_by_identity[key]
                if prior['remarks'] and prior['remarks'] not in notes:
                    notes.append(prior['remarks'])
        notes.append('현재 공개 원 강의실 보존; 중앙 변경표는 강의실 변경을 포함하지 않음')
        row['remarks'] = ' / '.join(notes)
        for field in ['courseCode', 'section', 'courseName', 'credits', 'professor',
                      'departments', 'departmentCredits', 'departmentClassifications',
                      'departmentRemarks', 'classification', 'sourceSchedule',
                      'sourceClassroom', 'campus', 'sourceId']:
            prior = previous_by_identity[key]
            if row[field] != prior[field]:
                educational_metadata_changes.append({'identity': key, 'field': field})
    assert not educational_metadata_changes
    assert unknown_delivery == ['0963201']
    counts = dict(Counter(row['scheduleStatus'] for row in result['courses']))
    assert counts == {'scheduled': 2353, 'unscheduled': 162, 'unrecognized': 56}
    result.update({'counts': counts, 'productionReady': False, 'completionClaim': False,
                   'partialKnownOrdinaryMeetingsOnly': True,
                   'individualOperatingPlansWholeReviewed': False,
                   'examMeetingsConfirmed': False,
                   'clockEvidence': 'Current BU 2026-2 undergraduate contract periods1-9 plus two identical current general offerings; common undergraduate interpretation requires root review, no period10 extrapolation',
                   'ordinaryTeachingEnd': '2026-12-14'})
    name = 'bu-current-whole-ordinary-partial-next-20261008.json'
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    target = ROOT / name
    if target.exists():
        assert target.read_text() == encoded, 'Immutable candidate already exists with different bytes'
    else:
        target.write_text(encoded)
    audit = {'date': '2026-10-08', 'candidate': name, 'candidateSHA256': digest(name),
             'previousCandidate': old_name, 'previousCandidateSHA256': old_sha,
             'sourceCandidate': source_name, 'sourceCandidateSHA256': digest(source_name),
             'wholeCount': 2571, 'counts': counts,
             'datedMeetingCount': sum(len(row['schedules']) for row in result['courses']),
             'originalEndMinuteRestored': True, 'sourceMetadataMismatchCount': 0,
             'examMeetingDatesOmitted': omitted_exam, 'individualUnresolvedDelivery': unknown_delivery,
             'clockEvidence': ['bu-current2026-2-contract-clock-evidence.json',
                               'bu-current-2semester-general-course-clock-crosscheck.json'],
             'clockScopeInferenceExplicit': True,
             'actualTeachingDates': 'bu-current-official-teaching-date-records.json',
             'actualTeachingGridCurrentRecheck': 'bu-current-teaching-grid-recheck-20261008.json',
             'termAndExamSource': {'sourceURL': 'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf',
                                  'sourceSHA256': digest('2026_2_juyo.pdf'),
                                  'literalExamPeriod': '12월 15~21 2학기 기말고사 기간',
                                  'ordinaryCutoffDerivation': 'Day before published final exam window; known regular timetable not replaced by guessed examination events.'},
             'currentDeltas': 'bu-current-exact-delta-recheck-20261008.json',
             'centralSearch': 'bu-current-central-operating-title-review-20261008.json',
             'pinnedNoticesExcludedFromSearchMatchClaims': True,
             'knownClosedCount': 55, 'knownClosedMatchedInitialCount': 52,
             'changesOnlyIdentitiesUnresolved': [row['courseCode'] + row['section']
                                               for row in result['courses']
                                               if not originals[row['courseCode'] + row['section']]['sourceOccurrences']],
             'finalActiveScopeVerified': False, 'finalRoomChangesVerified': False,
             'individualOperatingPlansWholeReviewed': False,
             'productionReady': False, 'completionClaim': False,
             'limits': ['All known dated meetings use actual school date grid, excluding five video replacement dates. December8/9 retain Friday source clocks with actual Tuesday/Wednesday date.',
                        'Current exact closed/time/professor updates are retained. Notice-only ten identities are not fabricated additions or name-matched replacements.',
                        'Partial ordinary candidate does not claim private individual plans read, final unseen room changes verified or examination appointments complete.']}
    (ROOT / 'bu-current-whole-ordinary-partial-next-audit-20261008.json').write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    assert digest(old_name) == old_sha
    print(json.dumps({'candidate': name, 'sha256': digest(name), 'counts': counts,
                      'datedMeetings': audit['datedMeetingCount'], 'omittedExamDates': omitted_exam}, ensure_ascii=False))


if __name__ == '__main__':
    prepare()
