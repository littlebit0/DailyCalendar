"""Current department scope only; historical objects are preserved."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
BASE = ROOT.parent
BASELINE = BASE / 'koreatech-unknown-2026-2.reservation-planned-v1.json'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
data = json.loads(BASELINE.read_text())
old = copy.deepcopy(data)
raw = json.loads((BASE / 'koreatech-2026-2-public-educational-rows-v1.json').read_text())['rows']
raw_by = {(r['nativeCourseCode'], r['nativeSection']): r for r in raw}
# Explicit printed section, professor, weekday block, and room. No section inference.
proofs = [
    ('IMA442', '01', 3, '국제경영론', '김태형', [(3,660,750,'K119'), (4,780,870,'K119')], []),
    ('CCT770', '01', 3, '경영데이터베이스및실습', '박은진', [(1,540,780,'K319')], []),
    ('CCT740', '01', 1, '경영통계및실습', '한상일', [(1,660,780,'K214'), (4,840,960,'K214')], []),
    ('CCT740', '02', 1, '경영통계및실습', '성지미', [(4,960,1080,'K214')], ['화01A~02B 개별 강의실 미게시']),
    ('CCT740', '03', 1, '경영통계및실습', '성지미', [(4,840,960,'K319')], ['화03A~04B 개별 강의실 미게시']),
    ('IMD900', '01', 2, 'e-Biz개론', '이상곤', [(2,660,780,'K119'), (3,780,840,'K119')], []),
]
def native_spans(text):
    spans=[]
    for part in text.split(','):
        m=re.fullmatch(r'([월화수목금])(\d+)([AB])~(\d+)([AB])',part)
        assert m, text
        day='월화수목금'.index(m[1])+1
        start=540+(int(m[2])-1)*60+(30 if m[3]=='B' else 0)
        end=540+(int(m[4])-1)*60+(60 if m[5]=='B' else 30)
        spans.append((day,start,end))
    return spans
by={(c['courseCode'],c['section']):c for c in data['courses']}
independent=[]
for code,section,pdf,title,prof,blocks,missing in proofs:
    c=by[code,section]
    r=raw_by[code,section]
    assert not c['schedules']
    assert r['professor']==prof
    assert r['title']==title or (code=='IMD900' and r['title']=='e-Biz개론(캡스톤디자인)')
    native=native_spans(r['rawSchedule'])
    assert set(b[:3] for b in blocks).issubset(native)
    assert bool(missing)==(len(blocks)!=len(native))
    dates=[]
    day=dt.date(2026,8,31)
    while day<=dt.date(2026,12,6):
        if day.isoformat() not in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02']:
            for wd,start,end,room in blocks:
                if day.isoweekday()==wd:
                    dates.append(dict(weekday=wd,startMinute=start,endMinute=end,classroom=room,date=day.isoformat()))
        day+=dt.timedelta(days=1)
    c['schedules']=dates
    c['scheduleStatus']='scheduled'
    # Replace only obsolete held notice on changed six; full raw metadata remains unchanged.
    c['remarks']=c['remarks'].replace('2026-07-28 공개 편람과 2026-07-30 메카트로닉스 시간표의 정확한 과목코드·분반·교시를 대조했습니다.', '2026-07-28 공개 편람의 식별자와 2026-2 산업경영학부 현재 시간표의 명시 분반·교수·교시·실을 대조했습니다.').replace(' 예약 보류: 현재 메카트로닉스 개별 강의실·시각 대응 미확인','')
    c['remarks']+=' 현재 2026-2 산업경영학부 공개 시간표의 실제 분반·교수·요일·시각·강의실과 공개 편람 원문을 대조한 부분 예약입니다. 경영학부 범위만 적용하며 학교 전체 교시 시각을 확정하지 않습니다. 현재 8월 31일 수정과 전산 우선 안내를 보존합니다.'
    if missing:
        c['remarks']+=' 일부 요일 강의실 미게시로 확인된 요일만 예약: '+', '.join(missing)+'.'
    c['metadata']['heldReason']=''
    c['metadata']['clockScope']='Current2026-2industrial-business-department-grid-only'
    c['metadata']['currentBusinessGridProof']=dict(attachmentSequence=pdf,printedTitle=title,printedSection=section,printedProfessor=prof,blocks=[dict(weekday=x[0],startMinute=x[1],endMinute=x[2],classroom=x[3]) for x in blocks],unresolvedNativeSegments=missing,nativePeriodExactSubsetVerified=True,titleVariant='Printed title omits existing native 캡스톤디자인 suffix' if code=='IMD900' else '',nativeCodeNotPrintedInDepartmentPdf=True,joinBasis='Whole native code/section retained; unique exact department title + explicitly printed section + professor + weekday/clock block match. Not an official code annotation in the PDF.',actualAttendanceConfirmed=False,partialRoomScope=bool(missing))
    independent.append(dict(courseCode=code,section=section,sourceId=c['sourceId'],sourceRawSchedule=r['rawSchedule'],printedTitle=title,printedSection=section,printedProfessor=prof,attachmentSequence=pdf,blocks=c['metadata']['currentBusinessGridProof']['blocks'],unresolvedNativeSegments=missing,expectedDatedMeetings=len(dates)))
changed={p[0:2] for p in proofs}
for a,b in zip(old['courses'],data['courses']):
    assert a['sourceId']==b['sourceId']
    if (a['courseCode'],a['section']) not in changed: assert a==b
    assert a['metadata']['originalEducationalFields']==b['metadata']['originalEducationalFields']
    if a['schedules']: assert a==b
assert len(data['courses'])==791
(ROOT/'koreatech-unknown-2026-2.business-partial-v3.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(ROOT/'independent-six-native-block-proof.json').write_text(json.dumps(dict(proofs=independent),ensure_ascii=False,indent=2)+'\n')
audit=dict(researchOnly=True,completionClaim=False,old48WholeObjectsDeepEqual=True,all791NativeIdentitiesPreserved=True,unchanged785ObjectsDeepEqual=True,oldDatedMeetings=1080,newScheduledCourses=6,newPartialRoomCourses=2,totalScheduledCourses=sum(bool(c['schedules']) for c in data['courses']),totalDatedMeetings=sum(len(c['schedules']) for c in data['courses']),newDatedMeetings=sum(p['expectedDatedMeetings'] for p in independent),baselineSha256=sha(BASELINE),currentWholeClosuresConfirmed=False,wholeGeneralClockClaim=False,universityProvenImpossible=False,sdkUsed=False,actualThreeModeDriveProof='Pending SDK slot; prepared positive candidate has not yet run actual model fixture.',newNativeCount=0,additionalDatabaseSection02='Native code not printed in new PDF/body; no new identity synthesized or alias made.',heldOtherDepartmentRows='No scope expansion from business grid to whole university.',otherHolds=['Rows without explicit printed section kept held; unique-title match alone not enough for this candidate.','F/L and B/L with online independent-learning portions kept held; no live or VOD occurrence times invented.','Social survey K317/K119 alternative rooms not arbitrarily selected.','New professor for CCT781 and changed title for IMC801 not silently reconciled.'])
(ROOT/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False))
