"""Integrate exact source-backed additions without replaying checkpoint152."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'work/university-research/resume-20261011'


def load(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


patches = []
koreatech = load(OUT / 'koreatech/candidate.json')
koreatech_old = load(OUT / 'koreatech/prior-whole.json')
old_by = {c['sourceId']: c for c in koreatech_old['courses']}
for row in koreatech['courses']:
    before = old_by[row['sourceId']]
    if row == before:
        continue
    # Unknown rooms remain unknown even when their published clocks are usable.
    row['metadata']['currentBusinessGridProof']['partialRoomScope'] = True
    patches.append({
        'asset': 'assets/timetable/koreatech-unknown-2026-2.json',
        'sourceId': row['sourceId'],
        'originalWholeObject': before,
        'proposedWholeObject': row,
        'evidence': 'work/university-research/resume-20261011/koreatech/proof.json',
    })

for item in load(OUT / 'khu/partial-clock-candidates.json'):
    row = copy.deepcopy(item['proposedWholeObject'])
    old_notice = '강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
    new_notice = ('개별 교수 계획서에 직접 명시된 월요일 수업만 반영했습니다. '
                  '수요일 수업은 교수·운영 대응이 확인되지 않아 보류합니다. '
                  '시험·휴일·미공개 보강은 추가하지 않았습니다.')
    for department, remark in row['departmentRemarks'].items():
        row['departmentRemarks'][department] = remark.replace(old_notice, new_notice)
    row['semanticOperatingReview']['sourcePlan'] = str(Path(item['sourceFile']).relative_to(ROOT))
    row['semanticOperatingReview']['sourcePlanSha256'] = item['sourceSHA256']
    assert digest(item['sourceFile']) == item['sourceSHA256']
    patches.append({**item, 'proposedWholeObject': row})

skku = load(OUT / 'skku/additive-date-candidates.json')
for item in skku['patches']:
    assert item['conditionalReviewRequired'] is False
    assert item['allDirectDatesWithinOriginalTermFrame'] is True
    assert digest(item['asset']) == item['assetBeforeSha256']
    assert digest(item['source']['cache']) == item['source']['cacheSha256']
    row = copy.deepcopy(item['proposedWholeObject'])
    row['sourcePartialCoverage'] = True
    row['semanticOperatingReview'] = {
        'sourcePartialCoverage': True,
        'publishedDatedScopeOnly': True,
        'actualAttendanceConfirmed': False,
        'sourceSnapshot': '2026-10-11',
        'sourceReceipt': 'work/university-research/resume-20261011/skku/additive-date-candidates.json',
        'unresolvedConditionsRetained': item['excludedOrHeldConditions'],
    }
    for department, remark in row['departmentRemarks'].items():
        row['departmentRemarks'][department] = remark.replace(
            '수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.',
            '일부 날짜·수업 방식은 계속 확인 중이며, 확인된 날짜만 부분 반영했습니다.',
        )
    patches.append({**item, 'sourceId': row['sourceId'], 'proposedWholeObject': row})

for item in load(OUT / 'donga/partial-clock-candidates.json'):
    assert digest(item['sourceEducationFile']) == item['sourceEducationSHA256']
    row = copy.deepcopy(item['proposedWholeObject'])
    for field in ['remarks', 'note']:
        if isinstance(row.get(field), str):
            row[field] = row[field].replace(
                '원문 예약표시와 실제 75분 수업 종료를 구분했습니다.',
                '이 부분 예약은 원문에 직접 적힌 시간창을 그대로 사용하며, 75분으로 단축하지 않았습니다.',
            )
    patches.append({**item, 'proposedWholeObject': row})

by_asset = {}
for patch in patches:
    by_asset.setdefault(patch['asset'], []).append(patch)

receipt = {'completionClaim': False, 'reprojectedCheckpoint152': False, 'assets': []}
baseline = OUT / 'before-integration'
baseline.mkdir(exist_ok=True)
prepared = []
for asset, changes in by_asset.items():
    path = ROOT / asset
    backup = baseline / path.name
    assert not backup.exists(), 'Do not overwrite an immutable baseline or replay integration'
    current = load(path)
    original_bytes = path.read_bytes()
    rows = {c['sourceId']: c for c in current['courses']}
    for change in changes:
        old = change['originalWholeObject']
        new = change['proposedWholeObject']
        assert rows[change['sourceId']] == old, change['sourceId']
        # Never remove already packaged reservations in this addition-only batch.
        assert all(meeting in new['schedules'] for meeting in old['schedules'])
        for field in ['sourceId', 'campus', 'academicYear', 'semester', 'courseCode',
                      'section', 'courseName', 'professor', 'sourceSchedule', 'sourceClassroom', 'period']:
            assert new.get(field) == old.get(field), (change['sourceId'], field)
    replacements = {c['sourceId']: c['proposedWholeObject'] for c in changes}
    current['courses'] = [replacements.get(c['sourceId'], c) for c in current['courses']]
    prepared.append((asset, changes, path, backup, original_bytes, current, replacements))

for asset, changes, path, backup, original_bytes, current, replacements in prepared:
    backup.write_bytes(original_bytes)
    write(path, current)
    receipt['assets'].append({
        'asset': asset, 'before': str(backup.relative_to(ROOT)),
        'beforeSha256': hashlib.sha256(original_bytes).hexdigest(), 'afterSha256': digest(path),
        'changedSourceIds': list(replacements),
        'addedMeetings': sum(len(c['proposedWholeObject']['schedules']) - len(c['originalWholeObject']['schedules']) for c in changes),
    })

write(OUT / 'integrated-source-proofs.json', patches)
write(OUT / 'integration-receipt.json', receipt)
print(json.dumps(receipt, ensure_ascii=False))
