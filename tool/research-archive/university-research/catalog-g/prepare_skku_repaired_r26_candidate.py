"""Preserve r25 and add only repaired, compatible published normal times.

No network, production changes, or actual attendance confirmation.
"""
import argparse
import ast
import hashlib
import collections
import copy
import datetime
import importlib.util
import json
import re
from pathlib import Path
from skku_inline_private_education_filter import EMAIL, PHONE, CONTACT_EXTENSION, CONTACT_LOCAL_PHONE, REMAINING_PRIVATE

P = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r25', P / 'prepare_skku_planned_regular_r25_candidate.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
CHECKPOINT = '20261008-r26-draft'
FREEZE = False

def write_candidate(path, value):
    if FREEZE:
        return base.immutable(path, value)
    body = (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode()
    path.write_bytes(body)
    return hashlib.sha256(body).hexdigest()

def all_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from all_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from all_strings(item)


def read(name):
    return json.loads((P / name).read_text())


def restriction_notes(record):
    tree = ast.parse((P / 'prepare_skku_research_candidate.py').read_text())
    expression = next(n.value for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'RESTRICTION' for t in n.targets))
    pattern = re.compile(ast.literal_eval(expression.args[0]), re.I)
    detail = record['detail'][0] if record['detail'] else {}
    notes = []
    for key, label in [('SUGANGDAESANG_HAKGWA', '수강 대상'), ('PRE_HAKSU_NAME', '선수과목'), ('FOREIGNER_GB_NM', '수강 조건'), ('BIGO', '수업 비고')]:
        if detail.get(key):
            notes.append(label + ': ' + detail[key])
    contexts = []
    texts = [detail.get('CLASS_INFO', '')] + [t for a in record['attachments'] for t in a.get('educationalOperatingContexts', [])]
    for text in texts:
        for match in pattern.finditer(text):
            context = re.sub(r'\s+', ' ', text[max(0, match.start()-100):min(len(text), match.end()+160)]).strip()
            if context and context not in contexts:
                contexts.append(context)
    if contexts:
        notes.append('계획서 수강 조건 원문: ' + ' / '.join(contexts))
    return notes


def main():
    global CHECKPOINT, FREEZE
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    args = parser.parse_args()
    FREEZE = args.freeze
    if FREEZE:
        CHECKPOINT = '20261008-r26'
    repaired = read('skku-inline-privacy-education-repair-audit.json')
    assert repaired['allTargetRequestsFinished'] and repaired['count'] == 548 and not repaired['stopped']
    proof = {r['offeringCode']: r for r in repaired['records']}
    repair_proof_path = P/'skku-inline-education-repaired-20261008-r26-proof.json'
    review_proof_path = P/'skku-repaired-r26-new-planned-whole-header-week-review.immutable.json'
    if FREEZE:
        repair_proof_sha = write_candidate(repair_proof_path, repaired)
        review_proof_sha = write_candidate(review_proof_path, read('skku-repaired-r26-new-planned-whole-header-week-review.json'))
    else:
        repair_proof_sha = hashlib.sha256((json.dumps(repaired, ensure_ascii=False, indent=2)+'\n').encode()).hexdigest()
        review_proof_sha = hashlib.sha256((json.dumps(read('skku-repaired-r26-new-planned-whole-header-week-review.json'), ensure_ascii=False, indent=2)+'\n').encode()).hexdigest()
    queue = read('skku-repaired-education-semantic-review-queue.json')
    assert queue['whole548Fetched'] and queue['fetchedCount'] == 548
    decisions = {r['offeringCode']: r for r in queue['decisions']}
    reviews = {r['offeringCode']: r for r in read('skku-repaired-education-individual-review-notes.json')['reviewed']}
    prior_tree = ast.parse((P/'prepare_skku_reviewed_ordinary_draft.py').read_text())
    prior_blocked = next(ast.literal_eval(n.value) for n in prior_tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'BLOCKED' for t in n.targets))
    async_decisions = {r['offeringCode']: r for r in read('skku-source32-untimed-classification-candidate.json')['decisions']}
    rules = read('skku-current-term-closure-rule-evidence.json')
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    manifest = {'universityId': 'skku', 'semester': '2026-2', 'completionClaim': False,
                'wholeOperatingAuditFinished': False, 'actualAttendanceConfirmed': False,
                'wholeCurrentCount': 2782, 'all548EducationalRepairRequestsFinished': True,
                'currentWholeCensusCheckedAt': read('skku-final-current-scope-check.json')['checkedAt'],
                'preservedR25ScheduledCourseObjects': 1180, 'preservedR21IndividualEvidenceCount': 422,
                'source32ClassificationOnlyNotTimetableImportCompletion': True,
                'educationalRepairProof': {'path': str(repair_proof_path), 'sha256': repair_proof_sha},
                'newWholeHeaderWeekReviewProof': {'path': str(review_proof_path), 'sha256': review_proof_sha},
                'campuses': []}
    totals = collections.Counter()
    added = []
    refreshed = []
    preserved = 0
    async_count = 0
    for campus in base.CAMPUSES:
        data = read(f'skku-{campus}-2026-2.partial-audited-20261008-r25.json')
        old = copy.deepcopy(data)
        for course in data['courses']:
            key = course['courseCode'] + '-' + course['section']
            if course['scheduleStatus'] == 'scheduled':
                preserved += 1
                continue
            if key in proof:
                record = proof[key]
                for department, old_note in course['departmentRemarks'].items():
                    # Preserve original raw/source notes; replace only the repaired plan-note segment.
                    lines = [line for line in old_note.splitlines() if not line.startswith('계획서 수강 조건 원문:')]
                    for note in restriction_notes(record):
                        if note not in lines:
                            lines.append(note)
                    course['departmentRemarks'][department] = '\n'.join(lines)
                refreshed.append(key)
            proposal = async_decisions.get(key)
            if proposal and proposal['targetScheduleStatus'] == 'unscheduled':
                assert course['sourceTeachingTypeCode'] == '32' and course['sourceConcentratedType'] == 'N'
                assert not course['schedules']
                course['scheduleStatus'] = 'unscheduled'
                course['scheduleEvidenceKind'] = 'publishedPrerecordedWithoutLiveAttendanceClock'
                course['timetableImportSupported'] = False
                for department, note in course['departmentRemarks'].items():
                    course['departmentRemarks'][department] = note + '\n학교가 사전제작 온라인 강좌로 공시했습니다. 원 공시시각은 실시간 출석시간으로 적용하지 않습니다.'
                async_count += 1
                continue
            if key not in proof:
                continue
            decision = decisions[key]
            review = reviews.get(key)
            if decision['reasons'] or (review and review['decision'].startswith('hold')):
                continue
            if key in prior_blocked and not (review and review['decision'].startswith('normal')):
                continue
            no_specific_signal = decision['decision'] == 'needsWholeHeaderAndRestrictionReview'
            reviewed_compatible = review and review['decision'].startswith('normal')
            if not no_specific_signal and not reviewed_compatible:
                continue
            row = proof[key]['sourceRow']
            assert row['SUUP_TYPE_CD'] in ('31', '33') and row['HAKBU_JIBJUNG_GB'] == 'N'
            frames = course['rawMeetingFrameForReviewOnly']
            if not frames or any(not frame['classroom'] or '미지정' in frame['classroom'] for frame in frames):
                continue
            residual = base.CLOCK.sub('', row['GYOSI_NAME'])
            # Exact printed parser frames are authoritative. Remaining annotation must be known OFF allocation.
            stripped = re.sub(r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})【([^】]+)】', '', row['GYOSI_NAME'])
            stripped = re.sub(r'【[\d.]+h\(ON\)\+[\d.]+h\(OFF\)】', '', stripped).strip(', ')
            if stripped:
                continue
            if row['SUUP_TYPE_CD'] == '33' and not any(t in row['GYOSI_NAME'] for t in ['h(ON)+1.5h(OFF)', '1h(ON)+2h(OFF)', '1h(ON)+3h(OFF)[4시간]']):
                continue
            meetings = []
            day = start
            while day <= end:
                if day.weekday() != 6 and day.isoformat() not in closed:
                    meetings.extend({**frame, 'date': day.isoformat()} for frame in frames if frame['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            if not meetings:
                continue
            course.update({'scheduleStatus': 'scheduled', 'schedules': meetings,
                           'period': {'startDate': start.isoformat(), 'endDate': end.isoformat()},
                           'unresolvedReasons': [], 'researchOnly': False,
                           'scheduleEvidenceKind': 'plannedRegularTimetable', 'actualAttendanceConfirmed': False,
                           'commonClosureDatesApplied': True,
                           'operatingReviewBasis': review['basis'] if reviewed_compatible else 'Current published normal clock and classroom; repaired educational context has no specific unresolved operating signal. Missing headers/topics are not cancellation evidence.',
                           'sourceEducationalOperatingEvidenceReference': {'file': repair_proof_path.name, 'offeringCode': key, 'weeklyTopicPresenceRequired': False}})
            for department, note in course['departmentRemarks'].items():
                course['departmentRemarks'][department] = note.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.', '학교 공시 정규 수업시간에 학기·휴업일을 적용했습니다. 실제 휴·보강 및 시험 시간은 학교 공지를 확인하세요.')
            added.append(key)
        for before, after in zip(old['courses'], data['courses']):
            assert before['sourceEducationalMetadata'] == after['sourceEducationalMetadata']
            assert before['sourceSchedule'] == after['sourceSchedule'] and before['professor'] == after['professor']
            if before['scheduleStatus'] == 'scheduled':
                assert before == after
        assert not any(pattern.search(value) for value in all_strings(data) for pattern in [EMAIL, PHONE, CONTACT_EXTENSION, CONTACT_LOCAL_PHONE, REMAINING_PRIVATE])
        data['registrationBoundaries'] = 'Preserved r25 scheduled1180 exact objects and individually reviewed422; repaired normal school-published planned clocks only. No actual attendance or exact individual exam/makeup claim. Prerecorded82 classification is untimed, not implemented timetable import.'
        data.update({'completionClaim': False, 'wholeOperatingAuditFinished': False, 'actualAttendanceConfirmed': False,
                     'source32ClassificationOnlyNotTimetableImportCompletion': True, 'all548EducationalRepairRequestsFinished': True})
        counts = collections.Counter(c['scheduleStatus'] for c in data['courses'])
        totals.update(counts)
        path = P / f'skku-{campus}-2026-2.partial-audited-{CHECKPOINT}.json'
        digest = write_candidate(path, data)
        manifest['campuses'].append({'campus': campus, 'path': str(path), 'sha256': digest, 'courseCount': len(data['courses']), 'scheduleCounts': dict(counts)})
    assert preserved == 1180 and async_count == 82
    manifest.update({'counts': dict(totals), 'newPlannedCourseCount': len(added), 'newPlannedCodes': added,
                     'source32NewUntimedClassificationCount': 82, 'source32ConcentratedStillHeldCount': 1,
                     'refreshedEducationalRemarksCount': len(refreshed), 'newDatedDeliveryModeOverrides': False})
    write_candidate(P / f'skku-partial-audited-{CHECKPOINT}-sha-manifest.json', manifest)
    print({'counts': dict(totals), 'newPlanned': len(added), 'async': async_count, 'restoredRemarks': len(refreshed)})


if __name__ == '__main__':
    main()
