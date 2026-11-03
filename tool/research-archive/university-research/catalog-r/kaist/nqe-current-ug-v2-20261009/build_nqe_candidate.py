"""Public current UG roster/grid only; retain AIC frozen object verbatim."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
import openpyxl

R=Path(__file__).parent
SRC=Path('work/university-research/root-kaist-public-followup-20261009')
book=SRC/'nqe-current-fall-schedule.xlsx'
s=openpyxl.load_workbook(book,data_only=True).worksheets[0]
assert s['A1'].value=='2026년 가을학기 강의시간표_20260826'
assert hashlib.sha256(book.read_bytes()).hexdigest()=='b37d95486f078f570a627fb712e2baf8cf6a227f7da86c0a585dda886464fabc'
merges={m.start_cell.coordinate:m for m in s.merged_cells.ranges}
def minutes(label):
    parts=re.fullmatch(r'(\d\d):(\d\d)-(\d\d):(\d\d)',label).groups()
    return int(parts[0])*60+int(parts[1]),int(parts[2])*60+int(parts[3])
def hhmm(n):
    return f'{n//60:02}:{n%60:02}'
def weekday(col):
    for c,stop,d in [(2,6,1),(7,12,2),(13,17,3),(18,23,4),(24,27,5)]:
        if c<=col<=stop:return d
    raise ValueError(col)
roster=[]
for row in range(27,38):
    roster.append(dict(sourceRow=row,nativeCode=s.cell(row,2).value,nativeClassification=s.cell(row,1).value,nativeTitle=s.cell(row,4).value,nativeProfessor=s.cell(row,11).value,nativeRemarks=s.cell(row,12).value))
assert len(roster)==11
assert len({r['nativeCode'].replace('.','')[3:] for r in roster})==11
allrows=[]
for r in roster:
    gridcode=r['nativeCode'].replace('.','')[3:]
    spans=[]
    grid=[]
    for row in s.iter_rows(min_row=4,max_row=23,min_col=2,max_col=27):
        for cell in row:
            if cell.value is None or not re.match(r'^\s*'+re.escape(gridcode)+r'(?!\d)',str(cell.value)):
                continue
            merge=merges.get(cell.coordinate)
            assert merge and merge.min_col==merge.max_col
            start=minutes(s.cell(merge.min_row,1).value)[0]
            end=minutes(s.cell(merge.max_row,1).value)[1]
            room=s.cell(3,cell.column).value
            span=dict(weekday=weekday(cell.column),startMinute=start,endMinute=end,classroom=room.replace('\n',' '))
            spans.append(span)
            grid.append(dict(topLeftCell=cell.coordinate,mergedRange=str(merge),nativeText=cell.value,nativeRoomCell=s.cell(3,cell.column).coordinate,nativeRoom=room,nativeStartClockCell=s.cell(merge.min_row,1).coordinate,nativeStartClock=s.cell(merge.min_row,1).value,nativeEndClockCell=s.cell(merge.max_row,1).coordinate,nativeEndClock=s.cell(merge.max_row,1).value,span=span))
    assert len(spans)==2,(r['nativeCode'],spans)
    dates=[]
    d=dt.date(2026,8,31)
    while d<=dt.date(2026,12,13):
        if not dt.date(2026,10,19)<=d<=dt.date(2026,10,23) and d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
            dates.extend(dict(p,date=d.isoformat()) for p in spans if p['weekday']==d.isoweekday())
        d+=dt.timedelta(days=1)
    sourceId=f"kaist/main/2026-2/nqe-20677/{r['nativeCode']}"
    title=' '.join(r['nativeTitle'].split())
    prof=' / '.join(x.strip() for x in r['nativeProfessor'].splitlines() if x.strip())
    remarks='공개 예약 계획, 실제 등교·온라인/실험 개별 운영 날짜 미확인. 원문2026가을 시간표의 강의실과 병합구간 시각을 그대로 사용합니다. 분반·수강번호·학점·수강제한은 이 문서에 미공개이며 분반은 빈 값입니다. EDU4.0 및 Cyber 강의실 이름으로 원격방식을 추론하지 않고 사용자방식 선택을 유지합니다. 자체8/31~12/18학기 중 학기말시험12/14전날까지 일반 예약만 제공합니다. 중간10/19~23와 공휴일은 보수적 제외, 실제 시험·보강·최신폐강/변경은 미확인입니다.'
    allrows.append(dict(sourceId=sourceId,campus='main',academicYear=2026,semester='2',courseCode=r['nativeCode'],courseName=title,section='',professor=prof,classification=r['nativeClassification'],credits=None,departmentCredits={},departments=['원자력및양자공학과'],departmentClassifications={'원자력및양자공학과':r['nativeClassification']},sourceSchedule=' / '.join(f"{'월화수목금토일'[p['weekday']-1]} {hhmm(p['startMinute'])}-{hhmm(p['endMinute'])} [{p['classroom']}]" for p in spans),sourceClassroom=' / '.join(dict.fromkeys(p['classroom'] for p in spans)),scheduleStatus='scheduled',schedules=dates,period=dict(startDate='2026-08-31',endDate='2026-12-18'),remarks=remarks,metadata=dict(researchOnly=True,completionClaim=False,sourceUrl='https://nuclear.kaist.ac.kr/study/schedule.php',publishedDate='2026-08-26',originalEducationalFields=r,sourceWorkbookSha256=hashlib.sha256(book.read_bytes()).hexdigest(),sourceSheet=s.title,sourceGridEvidence=grid,sourceGridCode=gridcode,sourceIdKind='Internal document/native-code locator, not official offering identifier',nativeSection=None,publishedEnrollmentNumber=None,currentActiveStatusVerified=False,actualAttendanceConfirmed=False,deliveryModeStatus='unknown-user-choice',nativeOperatingMethod=r['nativeRemarks'],scope='Published current roster rows27-37 foundation/major UG; right-hand graduate excluded',campusEvidence='Official department directions explicitly Daejeon291; current department room-column grid',regularReservationEndDerivedFromNextFinalStart=True)))
old=json.loads((R.parent/'kaist-main-2026-2.aic-dated-planned-v1.json').read_text())
data=copy.deepcopy(old)
data['sourceUrl']='https://nuclear.kaist.ac.kr/study/schedule.php'
data['publishedDate']=''  # Combined scope has no single publication date.
data['sourceCoverage']=[dict(sourceUrl=old['sourceUrl'],sourcePublishedDate=old['publishedDate'],nativeCourses=['AIC.20000']),dict(sourceUrl='https://nuclear.kaist.ac.kr/study/schedule.php',sourcePublishedDate='2026-08-26',nativeCourses=[r['nativeCode'] for r in roster])]
data['researchRevision']='nqe-current-ug-v2'
data['courses'].extend(allrows)
assert data['courses'][0]==old['courses'][0]
(R/'kaist-main-2026-2.nqe-ug-planned-v2.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
receipt=dict(sourceUrl='https://nuclear.kaist.ac.kr/study/schedule.php',downloadUrl=json.loads((SRC/'download-receipt.json').read_text())['url'],sourceDate='2026-08-26',sourceSheetTitle=s['A1'].value,sourceSha256=hashlib.sha256(book.read_bytes()).hexdigest(),scope='11 left-side undergraduate foundation/major roster rows27-37; right-side graduate not imported',courses=[dict(native=x['metadata']['originalEducationalFields'],grid=x['metadata']['sourceGridEvidence']) for x in allrows],clockBasis='Exact merged top/bottom row native HH:mm. Final grid row19:00–22:00 is180min, not30min inferred.',deliveryModeInference=False,completionClaim=False)
(R/'nqe-native-grid-education-proof.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
audit=dict(wholeCurrentUniversityCatalog=False,nativeNewUndergraduate=11,scheduled=12,dates=sum(len(c['schedules']) for c in data['courses']),newDates=sum(len(c['schedules']) for c in allrows),oldDeepPreservedCourses=1,oldDeepPreservedDates=10,graduateRosterRowsExcluded=13,nativeDotsPreserved=[r['nativeCode'] for r in roster if '.' in r['nativeCode']],unknownCreditsNotInvented=True,sectionsUnpublished=True,latestClosureWholeVerified=False,completionClaim=False)
(R/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False))
