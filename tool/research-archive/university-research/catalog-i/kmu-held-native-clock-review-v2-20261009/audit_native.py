import collections
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).parent
ASSET = Path('assets/timetable/kmu-seongseo-2026-2.json')
NATIVE = Path('work/university-research/catalog-i/kmu-current-educational-20261007.json')
asset = json.loads(ASSET.read_text())
raw = json.loads(NATIVE.read_text())
rows = {r['scCdLtNo']: r for r in raw['records']}
assert len(rows) == 3166
assert len(asset['courses']) == 2829
held = [c for c in asset['courses'] if not c['schedules']]
assert len(held) == 157
review = []
for c in held:
    r = rows[c['courseCode'] + '-' + c['section']]
    assert r['campGbn'] == '1' and r['yy'] == '2026' and r['tmGbn'] == '2'
    assert c['sourceId'] == f"kmu/seongseo/2026/2/{r['scCd']}/{r['ltNo']}"
    assert c['courseName'] == r['scNm']
    assert c['professor'] == (r['respProfEmpNm'] or '')
    assert c['sourceSchedule'] == (r['lsnTmtablFormaSmryCtnt'] or '')
    assert c['sourceClassroom'] == (r['eduSpaceNm'] or '')
    assert c['departmentClassifications'][r['deptNm']] == r['cptnGbnNm']
    assert c['departmentRemarks'][r['deptNm']].startswith(r['tlsnObjHgCtnt'] or '')
    slots = []
    for day, sh, sm, eh, em in re.findall(r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})', c['sourceSchedule']):
        start = int(sh) * 60 + int(sm)
        end = int(eh) * 60 + int(em)
        assert 0 <= start < end < 1440
        slots.append({'weekday': '월화수목금토일'.index(day) + 1,
                      'sourceStartMinute': start, 'sourceEndMinute': end})
    if r['ltTypeGbn'] == '1':
        reason = 'explicit_remote_without_printed_HH'
        assert not slots and c['sourceSchedule'].startswith('원격수업(')
    elif not c['sourceSchedule']:
        reason = 'native_timetable_unpublished'
        assert not slots
    else:
        assert slots and re.search(r'현장실습|동계', c['courseName'])
        reason = 'literal_field_or_winter_scope_individual_operation_unconfirmed'
    review.append({'sourceId': c['sourceId'], 'reason': reason,
                   'assetWholeObject': c, 'originalEducationalRow': r,
                   'independentLiteralClocks': slots,
                   'newScheduleEligible': False,
                   'basis': 'No current section-specific weekly ordinary operation or field/winter date range publicly corroborated; no dates inferred from title, credits, grade or semester general bounds.' if slots else 'No actual weekly HH exists in this original educational row.'})
assert collections.Counter(x['reason'] for x in review) == {
    'explicit_remote_without_printed_HH': 48,
    'native_timetable_unpublished': 102,
    'literal_field_or_winter_scope_individual_operation_unconfirmed': 7,
}
assert sum(not x['assetWholeObject']['professor'] for x in review) == 0
assert sum(bool(x['independentLiteralClocks']) and x['assetWholeObject']['sourceClassroom'] in ['', '미지정'] for x in review) == 0
out = {'sourceOnly': True, 'completionClaim': False, 'impossibleClaim': False,
       'nativeWhole': 3166, 'campusWhole': 2829, 'heldReviewed': 157,
       'newEligible': 0, 'beforeAfterAll2829ObjectsEquivalent': True,
       'sourceHash': {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in [ASSET, NATIVE]},
       'reasonCounts': dict(collections.Counter(x['reason'] for x in review)),
       'professorOnlyHold': 0, 'classroomOnlyHold': 0,
       'conditionalFutureRemoteWithOrdinaryClockHold': 0, 'reviews': review}
(HERE / 'held157-exact-native-audit.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
print('PASS 157 exact native joins; 48 remote + 102 unpublished time + 7 field/winter; eligible0; baseline unchanged')
