"""Correct overlooked explicit/encoded field teaching; never infer field clocks."""
import copy, hashlib, json
from pathlib import Path
R = Path(__file__).resolve().parent
base_name = 'cnu-unknown-2026-2.whole-checkpoint-next198-planned-regular186.json'
base = json.loads((R/base_name).read_text())
original = json.loads((R/'cnu-unknown-2026-2.whole-checkpoint-next-twelve-firstnormal-partial.json').read_text())
original_by_id = {c['sourceEducation']['courseId']: c for c in original['courses']}
blocked = ['1372-2007-00', '1372-3004-00', '1372-3006-00', '1101-7019-04', '1101-7019-51', '1101-7019-55']
out = copy.deepcopy(base)
changes = []
for c in out['courses']:
    cid = c['sourceEducation']['courseId']
    if cid not in blocked:
        continue
    old = copy.deepcopy(c)
    c.clear()
    c.update(copy.deepcopy(original_by_id[cid]))
    assert not c.get('schedules')
    plan = json.loads((R/'cnu-current-education'/f'{cid}.json').read_text())
    fields = [w['WKORD'] for w in plan['weeks'] if str(w.get('CLS_METHOD_FIELD', 0)) == '1']
    explanation = '주차별 현장 수업 표시가 있어 실제 날짜·시간·장소를 확인 중입니다. 현재 공시 교시와 강의실은 검색 정보로 유지하며 현장 수업을 임의로 복사하지 않습니다.'
    c['sourceEducation']['registrationStatus'] = 'blockedIndividualFieldOperationUnresolved'
    c['sourceEducation']['derivedBlockingExplanation'] = explanation
    c['sourceEducation']['fieldOperationReview'] = {'sourceResponseSHA256': plan['sourceResponseSHA256'], 'weeklyFieldFlags': fields, 'publishedSceneHours': plan['header'][0].get('LSN_MTHD_SCENE'), 'fieldClockRoomIndividuallyConfirmed': False}
    for dep, text in c['departmentRemarks'].items():
        c['departmentRemarks'][dep] = text + '\n' + explanation
    for k in ['professor', 'courseName', 'courseCode', 'section', 'classification', 'departmentClassifications', 'credits', 'departmentCredits', 'departments', 'sourceSchedule', 'sourceClassroom']:
        assert c[k] == old[k]
    assert c['sourceEducation']['originalEducationFields'] == old['sourceEducation']['originalEducationFields']
    changes.append({'courseId': cid, 'removedPlannedMeetings': len(old['schedules']), 'weeklyFieldFlags': fields, 'sourceResponseSHA256': plan['sourceResponseSHA256'], 'blockReason': 'Explicit outdoor/field-trip topic or encoded current field-teaching flag and scene hours; actual applicability/site/date/clock unconfirmed'})
for old, new in zip(base['courses'], out['courses']):
    if old['sourceEducation']['courseId'] not in blocked:
        assert old == new
out['verificationScope'] = 'Research corrected next192: actual12/172 unchanged,180 current published regular plans; six unresolved field-operation courses restored to blocked search rows. Prior next198 historical approval superseded for these six only.'
f = R/'cnu-unknown-2026-2.whole-checkpoint-next192-planned-regular180-fieldaudit-v2.json'
f.write_text(json.dumps(out, ensure_ascii=False, indent=2)+'\n')
a = json.loads((R/'cnu-next198-planned-regular186-candidate-audit.json').read_text())
a.update(candidate=f.name, candidateSHA256=hashlib.sha256(f.read_bytes()).hexdigest(), supersededBaseSHA256=hashlib.sha256((R/base_name).read_bytes()).hexdigest(), totalPlannedCourseIds=[x for x in a['totalPlannedCourseIds'] if x not in blocked], totalScheduledCourses=192, totalPlannedMeetings=a['totalPlannedMeetings']-sum(x['removedPlannedMeetings'] for x in changes), totalMeetings=a['totalMeetings']-sum(x['removedPlannedMeetings'] for x in changes), correctedFieldCourses=changes, actual12And172ObjectsUnchanged=True, allOther3882RowsUnchanged=True, prior198ApprovalSupersededForSix=True, noNewCandidateExpansion=True)
for k in ['plannedCourseIds', 'newPublishedRegularPlanCourses', 'newPlannedMeetings', 'allOther3861RowsUnchanged', 'previous171And3359MeetingsUnchanged']:
    a.pop(k, None)
(R/'cnu-next192-planned-regular180-fieldaudit-v2-candidate-audit.json').write_text(json.dumps(a, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k:v for k,v in a.items() if k in ['candidate','candidateSHA256','totalScheduledCourses','totalPlannedMeetings','totalMeetings','correctedFieldCourses']},ensure_ascii=False))
