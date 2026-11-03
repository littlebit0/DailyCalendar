"""Record full retained source semantic review of the exact 186-row late pool."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
load = lambda path: json.loads(path.read_text())
rows = load(ROOT / 'late186-full-education-review-pool.json')
native = {c['sourceId']: c for campus in ['seoul', 'global'] for c in load(PRIOR / f'hufs-{campus}-2026-2.whole-candidate.json')['courses']}
# Explicit individual semantic decisions, not a regex activation rule.
HOLDS = {
    0: 'Weekly schedule explicitly example only / Do not plan by it; actual operational-week allocation not confirmed.',
    1: 'Same full source example-only disclaimer; no actual weekly operating dates inferred.',
    2: 'Same full source example-only disclaimer; no actual weekly operating dates inferred.',
    31: 'Individual midterm in6th conflicts with standard own8th midterm placement; no direct actual date supplied.',
    35: 'Individual midterm7th or8th undecided; no direct actual date determines affected ordinary meeting.',
    60: 'Teacher-specific cancellation/makeup by student negotiation noted, not independently allocated; held conservatively for individual review.',
    73: 'Term museum visit explicitly required in methods; date/allocation to native classroom slots unknown.',
    91: 'Final exam14th inside ordinary interval, actual date/time not printed; cannot move to school final period.',
    97: 'Individual midterm7th conflicts with school own8th placement; no direct date supplied.',
    123: '15th makeup explicitly refers to Sept22 Tuesday while native is Thursday; underlying source cancellation/allocation unclear.',
    133: 'Individual midterm6th conflicts with school own8th placement; actual date unknown.',
    135: 'Final exam14th inside ordinary interval plus midterm replacement experience week; no direct final date/time/allocation.',
}
NO_MIDTERM_EXCLUSION = {
    5: 'Methods explicitly final examination only;8th Mid-term Period is not asserted as a class cancellation.',
    16: 'No individual8th midterm operation retained.',
    23: 'Methods midterm replaced by ongoing Eclass open-book quizzes; no allocated in-class midterm exam stated.',
    30: 'No individual8th midterm operation retained.',
    40: 'No individual8th midterm operation retained.',
    48: '8th explicitly 중간고사 없음; preserve ordinary weekly allocation.',
    62: 'Notes explicitly no midterm/final examination; assignments do not establish regular cancellation.',
    88: 'No individual8th midterm operation retained.',
    111: 'No individual8th midterm operation retained.',
    112: '8th explicitly No exam; own midterm range is not blanket lecture cancellation.',
    148: 'No individual8th midterm operation retained.',
    151: 'No individual8th midterm operation retained.',
}
decisions = []
for index, row in enumerate(rows):
    source_id = row['sourceId']
    course = native[source_id]
    path = Path(row['planPath'])
    plan = load(path)
    assert plan['fields'] == row['fields']
    assert plan['publicPlanMetadataStatus'] == 'published'
    f = row['fields']
    key = course['courseCode'] + course['section']
    assert f['identity'].endswith(key)
    assert f['schedule'].split('\n')[0] == course['sourceSchedule']
    assert float(f['creditsHours'].split('/')[0]) == course['credits']
    assert f['title'].startswith(course['courseName'])
    assert course['schedules'] and all(m['classroom'] and m['startMinute'] < m['endMinute'] for m in course['schedules'])
    individual_exam = index not in NO_MIDTERM_EXCLUSION and index not in HOLDS
    if individual_exam:
        assert '8th' in f['weekly'], (index, source_id)
    reason = HOLDS.get(index, 'Full retained methods/notes/delivery/all weekly operation fields and native raw department remarks reviewed. Late makeup/final/no-class statements interpreted against own current Dec8–14/Dec15–21 calendar, not from15th number alone. No evidenced alternative allocation changes ordinary Sep1–Dec7 outside individually excluded midterm interval.')
    special_notes = []
    if index == 5:
        special_notes.append('15:10–15:30 denotes lateness classification, native start15:00 not overridden.')
    if index in {21, 23, 74, 76, 84, 92, 93, 94, 95, 145, 170, 177, 178}:
        special_notes.append('Assessment delivery or missing assessment HH is confined to relevant exam scope; no ordinary course-wide mode inferred.')
    if index == 152:
        special_notes.append('Native Tue2 and Wed5–6; notes explicitly midterm in Wednesday two-hour class. Only Wed10/21 omitted; Tue10/20 ordinary reservation preserved. No exam event/time invented.')
    if index == 154 or index == 155 or index == 156 or index == 157 or index == 158:
        special_notes.append('Military enlistment is general attendance policy, not military-only course exclusion.')
    if index == 182:
        special_notes.append('Native current Tue8/Thu4–5 and current plan header agree; raw note records prior Wed→Thu change. Old Wed not revived.')
    if index == 185:
        special_notes.append('Individual printed final Dec15–19 is narrower than own Dec15–21 final period; both retained, no final event generated.')
    decisions.append({**row, 'poolIndex': index, 'nativeCourse': course, 'nativeRawRemarks': course['departmentRemarks'], 'planSha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'wholeRetainedOperatingTextReviewed': True, 'decision': 'heldIndividualOperationUnresolved' if index in HOLDS else 'ordinaryReservationEligible', 'reason': reason, 'individualMidtermExclude': individual_exam, 'midtermExceptionWeekdays': [3] if index == 152 else None, 'noMidtermExclusionReason': NO_MIDTERM_EXCLUSION.get(index), 'specialInterpretations': special_notes, 'noWeekNumberDateInference': True, 'sourceSnapshotDate': '2026-10-08', 'freshRequeryPerformed': False})
output = {'sourceOnly': True, 'sdkUsed': False, 'productEdited': False, 'completionClaim': False, 'reviewScope': 'All186 retained educational plans, all weekly operation fields, native raw department remarks and exact headers', 'counts': {'reviewed': len(decisions), 'eligible': sum(d['decision'] == 'ordinaryReservationEligible' for d in decisions), 'held': len(HOLDS)}, 'decisions': decisions}
(ROOT / 'late186-full-operation-decisions.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(output['counts'])
