import copy
import hashlib
import json
from pathlib import Path

base = Path('work/full-timetable-audit-20261012/kmou-current-new-notices')
path = base / 'kmou-new-weekly-candidate.json'
data = json.loads(path.read_text())
old = json.loads(Path('assets/timetable/kmou-unknown-2026-2.json').read_text())
assert not ({c['sourceId'] for c in old['courses']} & {c['sourceId'] for c in data['courses']})
for course in data['courses']:
    course['universityId'] = 'kmou'
    course['campusName'] = data['campusName']
    course['departmentCredits'] = {}
    course['departmentClassifications'] = {}
    course['departmentRemarks'] = {}
    course['period'] = {'startDate': '2026-09-01', 'endDate': '2026-12-07'}
    course['sourcePeriodScope'] = '공식 학사력 정규수업 기간. 12/8~14 지정보강과 12/15~21 기말시험은 반복수업으로 추정하지 않음.'
    course['remarks'] += ' 정규 반복수업은 12월 7일까지 적용. 학교 휴일·지정보강·개별 변경 수업은 이 공개 주간표에 개별 날짜가 없으므로 생성하지 않음.'
    # Adjacent native periods of one offering are a continuous weekly block.
    # Original clock periods stay retained for audit and no date is generated.
    blocks = []
    for slot in sorted(course['schedules'], key=lambda s: (s['weekday'], s['startMinute'], s['classroom'])):
        if blocks and blocks[-1]['weekday'] == slot['weekday'] and blocks[-1]['classroom'] == slot['classroom'] and blocks[-1]['endMinute'] + 10 == slot['startMinute']:
            blocks[-1]['endMinute'] = slot['endMinute']
        else:
            blocks.append(copy.deepcopy(slot))
    course['schedules'] = blocks
    course['periodEvidence'] = {'sourceUrl': 'https://www.kmou.ac.kr/common/nttFileDownload.do?fileKey=d8612744c6304fff8990e6bfa13a46ad', 'scope': '학교 학사력 정규수업 종료 2026-12-07'}
    course['clockEvidence'] = {'sourceUrl': 'https://www.kmou.ac.kr/common/nttFileDownload.do?fileKey=2608eb19874cb65d52aaa87975ed4bc9', 'sha256': 'a4be7d78e906fe197798212612129b976f653c7c0f24f63246ba2719b7fead3a', 'page': 2}
data.pop('candidateAcceptanceRequired', None)
data['researchOnly'] = False
data['productionIntegrationEnabled'] = True
data['sourceNotice'] = '공식 학과별 공개 주간표 일부. 개별 날짜 일정 아님. 확인된 과목번호·분반·교시 그대로 유지하며 학교 전체 지원 완료를 뜻하지 않음. 충돌 강좌·미공개 실습시간은 제외.'
target = Path('assets/timetable/kmou-public-weekly-2026-2.json')
target.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
catalog = Path('assets/timetable/catalog.json')
index = json.loads(catalog.read_text())
if str(target) not in index:
    index.append(str(target))
catalog.write_text(json.dumps(index, ensure_ascii=False, indent=2)+'\n')
receipt = {'originalSourceSha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'addedOfferings': len(data['courses']), 'previousOfferingsPreserved': len(old['courses']), 'verificationPending': True, 'wholeUniversityCompletion': False, 'weeklyPeriod': {'startDate': '2026-09-01', 'endDate': '2026-12-07'}, 'explicitMakeupDatesGenerated': False}
Path('work/all-university-completion-20261012/kmou-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(receipt))
