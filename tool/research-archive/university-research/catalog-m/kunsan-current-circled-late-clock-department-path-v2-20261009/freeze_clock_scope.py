import hashlib
from html.parser import HTMLParser
import json
import pathlib
import re

out = pathlib.Path(__file__).resolve().parent
base = out.parent
root = out.parents[3]
def read(path):
    return json.loads(path.read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def save(name, value):
    (out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
receipt = read(out / 'current-science-registration-guide-education.json')
guide = receipt['currentGuide']
assert '2026학년도 2학기 수강신청 안내 ' in guide['nativeDocumentOpeningEducationLines']
assert guide['circledPeriodSymbolsPresentInReadableText'] == []
assert guide['normalStatus'] == 200
assert guide['sha256'] == 'b1b1f82ce744299ae51876dc177c8bd53118b6905efb1db928becad7878b4b4b'
fragment = guide['nativeClockEducationFragment']
new_clock = {}
for index, line in enumerate(fragment):
    match = re.fullmatch(r'(\d+)교시', line.strip())
    if match:
        time = re.fullmatch(r'(\d\d):(\d\d)\s*~\s*(\d\d):(\d\d)', fragment[index + 1].strip())
        assert time
        hour1, minute1, hour2, minute2 = map(int, time.groups())
        new_clock[int(match[1])] = [hour1 * 60 + minute1, hour2 * 60 + minute2]
assert set(new_clock) == set(range(1, 10))
class CellParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.cells = []
        self.parts = None
    def handle_starttag(self, tag, attrs):
        if tag in ('td', 'th'):
            self.parts = []
    def handle_data(self, data):
        if self.parts is not None:
            self.parts.append(data)
    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.parts is not None:
            self.cells.append(' '.join(' '.join(self.parts).split()))
            self.parts = None
old_clock_file = base / 'kunsan-current-clock-20261008.html'
parser = CellParser()
parser.feed(old_clock_file.read_text())
old_clock = {}
for index, cell in enumerate(parser.cells):
    match = re.fullmatch(r'(\d+)교시', cell)
    if match:
        time = re.fullmatch(r'(\d\d):(\d\d)-(\d\d):(\d\d)', parser.cells[index + 1])
        if time:
            hour1, minute1, hour2, minute2 = map(int, time.groups())
            old_clock[int(match[1])] = [hour1 * 60 + minute1, hour2 * 60 + minute2]
assert set(old_clock) == set(range(1, 11))
assert all(old_clock[period] == clock for period, clock in new_clock.items())
current_files = sorted((root / 'assets/timetable').glob('kunsan-*-2026-2.json'))
current = {c['sourceId']: c for path in current_files for c in read(path)['courses']}
pending_files = [base / f'kunsan-{campus}-2026-2.published-regular-1125-late-numeric-partial-next-20261008.json'
    for campus in ('unknown', 'saemangeum')]
pending = {c['sourceId']: c for path in pending_files for c in read(path)['courses']}
assert len(current) == len(pending) == 1718 and current.keys() == pending.keys()
changed = [key for key in current if current[key] != pending[key]]
key = 'kunsan/unknown/2026/2/116289/01'
assert changed == [key]
assert sum(bool(c['schedules']) for c in current.values()) == 1124
assert sum(len(c['schedules']) for c in current.values()) == 22971
assert sum(bool(c['schedules']) for c in pending.values()) == 1125
assert sum(len(c['schedules']) for c in pending.values()) == 22984
old = current[key]
proposal = pending[key]
assert old['schedules'] == []
assert proposal['sourceSchedule'] == '금9 10 11 [예술관-5403]'
assert proposal['sourceClassroom'] == '예술관-5403'
assert old['courseCode'] == proposal['courseCode'] == '116289'
assert old['section'] == proposal['section'] == '01'
assert proposal['professor'] == old['professor'] == '이승희'
changed_fields = {field for field in proposal if proposal[field] != old.get(field)}
assert changed_fields == {'remarks', 'scheduleStatus', 'schedules', 'sourceEducation', 'period'}
expected_dates = ['2026-09-04', '2026-09-11', '2026-09-18', '2026-10-02', '2026-10-16',
    '2026-10-30', '2026-11-06', '2026-11-13', '2026-11-20', '2026-11-27', '2026-12-04',
    '2026-12-08', '2026-12-09']
assert [s['date'] for s in proposal['schedules']] == expected_dates
assert all((s['startMinute'], s['endMinute'], s['classroom']) == (1030, 1140, '예술관-5403')
    for s in proposal['schedules'])
assert proposal['sourceEducation']['unresolvedSourcePeriodScope'] == [
    {'sourceWeekday': 5, 'sourcePeriodLiteral': '11', 'sourceClassroom': '예술관-5403'}]
save('existing-unprojected-late-one-education-review.json', {
    'newDocumentEligibleOfferings': 0,
    'existingResearchPendingNative': 1, 'existingResearchPendingAppointments': 13,
    'sourceId': key, 'currentProductCourse': old, 'existingFrozenResearchCourse': proposal,
    'changedFields': sorted(changed_fields), 'other1717WholeObjectsExact': True,
    'currentProductScope': {'native': 1718, 'scheduled': 1124, 'datedAppointments': 22971,
        'fullyHeld': 496, 'explicitOCUKCUUntimed': 98, 'numericAndMixedPartial': 324},
    'olderNextResearchScope': {'native': 1718, 'scheduled': 1125, 'datedAppointments': 22984,
        'fullyHeld': 495, 'explicitOCUKCUUntimed': 98, 'numericMixedLatePartial': 325},
    'notYetProjectedEvidence': {'productionRegisteredInFrozenAudit': False,
        'actualAssetStillEmptySchedules': True,
        'reason': 'Existing Oct8 artifact is expressly research-next/productionRegistered=false; actual current source assets still use1124 scope. No more specific historical reason for parent not projecting it is recorded, so none is invented.',
        'clockBoundary': 'Only literalFriday9+10 from existing current1–10 official clock. New guide corroborates9 only;11 remains held. No19:10 extrapolation.',
        'dateBoundary': 'OwnAug31–Dec17 semester, ordinary+exactFri makeupDec8Tue/Dec9Wed toDec10;13 source dates. No individual early-end or exam-attendance claim.'},
    'verification': 'PASS independent identity/13literal dates/HH/room/1717full-object comparison; actual model verification from prior frozen fixture remains historical, no SDK rerun this task.',
})
remaining_path = base / 'kunsan-current-remaining-495-review-next-20261008.json'
remaining = read(remaining_path)
save('current-clock-scope-and-remaining-audit.json', {
    'sourceOnly': True, 'completionClaim': False, 'impossibleClaim': False,
    'focusedActualPublicRoute': 'Previously observed science-undergraduate current notice1384451→actual first published attachment187371. Prior audit held title/link only; new actual attachment SHA not found in earlier catalog-m receipts.',
    'currentNewGuideNumericClock': new_clock,
    'existingCurrentOfficialPageClock': old_clock,
    'comparison': {'sharedPeriods1Through9Exact': True, 'conflictingClockPeriods': [],
        'currentGuideUnprinted': [10, 11, 12, 13], 'existingPageUnprinted': [11, 12, 13],
        'circledGlyphClockPublishedInNewGuide': False, 'period10ExistingProofRetained': True,
        'absenceDoesNotShortenPreviouslySupportedScope': True},
    'remainingResearch495Counts': remaining['reasonCounts'],
    'remainingOriginal495Sha256': digest(remaining_path),
    'remainingResearch325PartialBoundary': 'Whole ASCII-only known fragments retained; actual circled run/day/rooms unchanged and not normalized into integer periods.',
    'newEligibleNative': 0, 'newDatedAppointments': 0,
    'separateExistingUnprojectedCandidate': 'existing-unprojected-late-one-education-review.json',
    'inputSha256': {str(p.relative_to(root)): digest(p) for p in current_files + pending_files +
        [old_clock_file, remaining_path, base/'README.md', base/'kunsan-current-circled-period-single-search-v1-20261009.json',
         base/'kunsan-current-calendar-operating-review-20261008.json']},
    'boundaries': {'sdkUsed': False, 'productModified': False, 'oldFrozenModified': False,
        'AGENT_MEMORYModified': False, 'protectedPortalOpened': False,
        'guessedEndpointGrid': False, 'graduateLanguageOrOtherSchoolClockBorrowed': False,
        'individualCampusInferred': False, 'fullDocumentOrContactsSaved': False},
    'remainingEvidence': ['Actual current circled①–⑬ undergraduate class-hour correspondence',
        'Current explicit regular11–13 HH boundaries', 'Exactoffering exceptions/remote/clinical/intensive dates',
        'Latest whole active/closure and currently unprintedJST actualtime'],
})
save('SHA256SUMS.json', {'files': {p.name: digest(p) for p in sorted(out.iterdir())
    if p.is_file() and p.name != 'SHA256SUMS.json'}, 'newEligibleNative': 0,
    'existingResearchPendingNative': 1, 'sdkUsed': False, 'completionClaim': False})
print('PASS guide1–9=currentpage1–9; new0; pending1/13+1717exact', digest(out/'SHA256SUMS.json'))
