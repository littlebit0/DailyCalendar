"""Map published native halfslots only; retain uncertainty and medical originals."""
import copy
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

base = Path('work/all-university-completion-20261012')
rawbase = Path('work/university-research/catalog-c/jbnu-native-search-metadata-safe-union-v8-20261009')
clock = json.loads(Path('work/full-timetable-audit-20261012/jbnu-clock-followup-c/clock-proof.json').read_text())
calendar = base / 'root-sources/jbnu-current-2026fall-calendar.html'
calendar_text = calendar.read_text()
for date, title in [('2026-09-01', '제2학기 개강'), ('2026-12-22', '제2학기 종강')]:
    if not re.search(r'<dt>' + date + r'</dt>\s*<dd>' + title, calendar_text):
        raise SystemExit('Source semester not established')
period = {'startDate': '2026-09-01', 'endDate': '2026-12-22'}
starts = clock['absoluteStartMinutes']
weekdays = {label: index + 1 for index, label in enumerate('월화수목금토일')}
output = base / 'jbnu-weekly-candidates'
output.mkdir(exist_ok=True)
held_medical = []
held_clocks = []
counts = Counter()
identities = set()
for source_path in sorted(rawbase.glob('jbnu-*.native-search-safe-union-v8.json')):
    source = json.loads(source_path.read_text())
    result = copy.deepcopy(source)
    result['courses'] = []
    for native in source['courses']:
        if native['sourceId'] in identities:
            raise SystemExit('Repeated native identity')
        identities.add(native['sourceId'])
        if '의학과' in native['departments']:
            held_medical.append({'sourceId': native['sourceId'], 'code': native['courseCode'], 'section': native['section'], 'title': native['courseName'], 'reason': 'Existing dated medical document has no code/section identity crosswalk and contains professor/day/room conflicts; do not duplicate or overwrite it by title.'})
            continue
        row = copy.deepcopy(native)
        row['sourceUrl'] = source['sourceUrl']
        row['sourceMetadataOnly'] = False
        row['period'] = dict(period)
        row['sourceOperatingHolds'] = []
        text = row['sourceSchedule']
        tokens = [item.strip() for item in text.split(',')]
        slots = []
        unknown = []
        for token in tokens:
            m = re.fullmatch(r'([월화수목금토일])\s+(\d+-[AB])', token)
            if not m or m[2] not in starts:
                unknown.append(token)
            else:
                slots.append((weekdays[m[1]], starts[m[2]]))
        if unknown:
            row['schedules'] = []
            row['scheduleStatus'] = 'unrecognized'
            row['sourceOperatingHolds'] = ['Absolute undergraduate halfslot not established: ' + ', '.join(unknown)]
            held_clocks.append({'sourceId': row['sourceId'], 'nativeTokens': unknown})
        else:
            meetings = []
            # Each native field explicitly states 30-minute units; UI ends stay
            # on that grid as requested, without claiming 50/75-minute breaks.
            for day, minute in sorted(set(slots)):
                if meetings and meetings[-1]['weekday'] == day and meetings[-1]['endMinute'] == minute:
                    meetings[-1]['endMinute'] = minute + 30
                else:
                    meetings.append({'weekday': day, 'startMinute': minute, 'endMinute': minute + 30, 'classroom': row['sourceClassroom'].strip()})
            row['schedules'] = meetings
            row['scheduleStatus'] = 'scheduled' if meetings else 'unrecognized'
        row['remarks'] = '공식 JUMP 공개 개설강좌의 원문 과목코드·분반·교수·강의실·요일/교시입니다. 공식 현재 배포 학부 지침서와 원자료의 30분 단위에 따라 주간 시간표를 표시합니다. 강의실이 여러 개면 원문 전체를 유지하며 교시별 배정은 추정하지 않습니다. 학기 밖 반복은 적용하지 않으며 보강·임상·집중수업 개별 날짜는 생성하지 않습니다.'
        if row['sourceOperatingHolds']:
            row['remarks'] += ' 미확인 교시는 시간표 추가를 보류하고 원문만 표시합니다.'
        row['departmentRemarks'] = {label: row['remarks'] for label in row['departments']}
        row['clockSourceUrl'] = clock['manualUrl']
        row['clockSourcePage'] = 16
        result['courses'].append(row)
        counts[row['scheduleStatus']] += 1
    result['sourceRowCount'] = len(result['courses'])
    result['researchOnly'] = True
    result['sourceCatalogFamilies'] = ['native undergraduate public code-section offerings with source-backed halfslot grid']
    result['clockEvidence'] = {'url': clock['manualUrl'], 'sha256': clock['manualSha256'], 'page': 16, 'officialDistributionYear': 2026, 'exampleScreenshotYear': 2024, 'gridMinutes': 30, 'supportedStartLabels': sorted(starts)}
    result['periodEvidence'] = {'url': 'https://www.jbnu.ac.kr/mobile/academic/schedule.do', 'sha256': hashlib.sha256(calendar.read_bytes()).hexdigest(), 'startTitle': '제2학기 개강', 'endTitle': '제2학기 종강, 기말시험 완료'}
    result['coverage'] = 'Native whole-public undergraduate query minus33 medically ambiguous identities held to preserve existing dated document. Unconfirmed late halfslots remain searchable but unscheduled. Whole operating completion not established.'
    (output / f"jbnu-{source['campus']}-2026-2.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
receipt = {'nativeUniqueOfferings': len(identities), 'candidateOfferings': sum(counts.values()), 'scheduleStatus': dict(counts), 'medicalNativeIdentitiesHeld': held_medical, 'clockRowsHeld': held_clocks, 'existingMedicalDocumentPreserved': 33, 'verificationPending': True, 'productApplied': False, 'wholeCompletion': False}
(base / 'jbnu-weekly-candidate-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print({key: value for key, value in receipt.items() if key not in ['medicalNativeIdentitiesHeld', 'clockRowsHeld']})
