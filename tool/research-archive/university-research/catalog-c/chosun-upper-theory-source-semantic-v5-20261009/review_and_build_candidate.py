from pathlib import Path
import json,hashlib,re,copy,html,collections
from datetime import date,timedelta
import pdfplumber
P=Path(__file__).parent
F=P.parent.parent/'catalog-f'/'chosun'
V4=P.parent/'chosun-current-final-future-review-20261009'
pdf=Path('/private/tmp/chosun-nurse-current-pdf-response')
assert hashlib.sha256(pdf.read_bytes()).hexdigest()=='33aeea14356f441115900f77709f5a84975134f65830b0d321c693cf08589e8b'
rows=json.loads((F/'chosun-nurse-current-education-source-20261008.json').read_text())['educationRows']
selected=[r for r in rows if r['heldReasons']==['upperGradeClinicalIntensiveDatesUnverified']];assert len(selected)==20
with pdfplumber.open(pdf) as doc:
 assert len(doc.pages)==1
 page=doc.pages[0];text=page.extract_text();assert '2026학년도 2학기' in text and '주간 시간표' in text and '2026.09.7' in text
 table=page.find_tables()[0];data=table.extract();headers=data[0];groups={};day=grade=None
 for ri,v in enumerate(data[1:],1):
  if v[0]:day=v[0]
  if v[1] and re.fullmatch('[1-4]',v[1]):grade=int(v[1])
  groups[ri]=dict(nativeWeekdayLabel=day,nativeGradeLabel=str(grade),nativeGroup='간호학과 '+str(grade)+'학년')
 proof=[]
 for r in selected:
  ri,ci=r['nativeTableRow'],r['nativeTableColumn'];actual=data[ri][ci];box=table.rows[ri].cells[ci]
  assert actual==r['nativeCellText'] and all(abs(x-y)<.2 for x,y in zip(box,r['bbox']))
  group=groups[ri];assert group['nativeGradeLabel']==str(r['grade']) and '월화수목금'.index(group['nativeWeekdayLabel'])+1==r['weekday']
  clean=re.sub(r'\s+',' ',actual).strip();m=re.fullmatch(r'(.*?)\((\d{2})\)\s*([가-힣]{2,5})\s+(.+)',clean);assert m
  assert (m[1].strip(),m[2],m[3],m[4].strip())==(r['courseName'],r['section'],r['professor'],r['classroom'])
  assert not any(k in actual for k in ['실습','실기','시뮬','집담회','자율학습'])
  clock=[]
  for hi,h in enumerate(headers):
   if not h:continue
   tm=re.search(r'(\d\d):(\d\d)~(\d\d):(\d\d)',h)
   if tm:
    b=table.rows[0].cells[hi];clock.append(dict(literal=h,x0=b[0],x1=b[2],startMinute=int(tm[1])*60+int(tm[2]),endMinute=int(tm[3])*60+int(tm[4])))
  first=next(h for h in clock if abs(h['x0']-box[0])<.2);last=next(h for h in clock if abs(h['x1']-box[2])<.2)
  assert first['startMinute']==r['firstHeader']['startMinute'] and last['endMinute']==r['lastHeader']['endMinute']
  assert not(r['weekday']==3 and first['startMinute']<780 and last['endMinute']>720)
  proof.append(dict(sourceId=r['sourceId'],sourcePDFSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),nativeTableRow=ri,nativeTableColumn=ci,bbox=list(box),nativeCellText=actual,courseName=r['courseName'],section=r['section'],professor=r['professor'],classroom=r['classroom'],weekday=r['weekday'],printedGroup=group,firstIndependentHeader=first,lastIndependentHeader=last,sourceSpecificClinicalAllocationPublishedForThisTheoryCell=False,gradeOnlyDerivedHoldResolved=True,curriculumHourDifferenceDoesNotPublishOperatingDates=True,decision='publishedCurrentTheoryWeeklyReservation',actualAttendanceConfirmed=False))
notice=Path('/private/tmp/chosun-nurse-233477-fresh.html').read_text()
body=re.search(r'<div class="view-con">(.*?)</div>',notice,re.S).group(1)
body=html.unescape(re.sub('<[^>]+>',' ',body));body=re.sub(r'\s+',' ',body).strip()
assert '사례기반종합평가(01) 화 5A~7B ☞ 목요일 2A~4B' in body and '사례기반종합평가(06) 화 5A~7B 신규 개설' in body
assert not any(k in body for k in ['집중','격주','회전','임상일정','이론수업 기간'])
oldFile=V4/'chosun-unknown-2026-2.current-final-future-source-review-candidate-v4.json';oldBytes=oldFile.read_bytes();(P/'baseline-v4-frozen.json').write_bytes(oldBytes)
previous=json.loads(oldBytes);new=copy.deepcopy(previous);byid={r['sourceId']:r for r in selected};holidays={'2026-09-24','2026-09-25','2026-09-26','2026-09-29','2026-10-03','2026-10-05','2026-10-09'}
for c in new['courses']:
 if c['sourceId'] not in byid:continue
 r=byid[c['sourceId']];assert not c['schedules'];dates=[];d=date(2026,9,1)
 while d<=date(2026,12,7):
  ds=d.isoformat()
  if d.isoweekday()==r['weekday'] and ds not in holidays and not '2026-10-20'<=ds<='2026-10-26':dates.append(dict(date=ds,weekday=r['weekday'],startMinute=r['firstHeader']['startMinute'],endMinute=r['lastHeader']['endMinute'],classroom=r['classroom']))
  d+=timedelta(days=1)
 oldNote=next(iter(c['departmentRemarks'].values()));suffix=oldNote.split(' 날짜 변환 보류 사유:',1)[0]
 note=('공개 정규 주간 예약이며 실제 출석·개별 운영 확정이 아닙니다. 상급학년이라는 값만으로 이론 셀 전체를 보류했던 파생 기준을 교정했습니다. 현재2026-2 9/7 시행용 주간표의 직접 학년·요일·분반·교수·강의실·인쇄 시작/끝을 독립 대조했습니다. 학점/이론시수와 인쇄칸 길이 차이는 기록상의 주의점이며 집중주·단축강의·격주 날짜를 추정하는 근거로 사용하지 않습니다. 인쇄 예약 칸 전체를 그대로 사용하고 실제 수업분을 임의로 줄이지 않습니다. 같은 표의 실습·시뮬레이션·집담회·자율학습과 이 이론 셀은 별도입니다. 임상 실습 배치나 개인별 날짜가 확인되지 않은 실습 셀은 계속 보류합니다. 과목코드·학점·이수구분 미공개, 물리캠퍼스 unknown, 문서위치 내부ID를 보존하며 같은제목 다른셀을 임의 합치지 않습니다. 현재 학교 자체개강9/1,중간10/20~26,12/8이후보강,12/15~21기말을 기준으로12/7까지 정규 예약하며 명시휴업일과중간기간을 제외합니다. 과목별 시험·보강·휴강·임상운영은 여전히 미확인입니다. 학교 전체폐강 대조 미완료. ')
 c.update(remarks=note,departmentRemarks={g:note for g in c['departments']},period=dict(startDate='2026-09-01',endDate='2026-12-07'),schedules=dates,scheduleStatus='scheduled')
 c['sourceEducation']['upperTheoryOrdinaryReservationReview']=dict(resolvedDerivedHoldReason='upperGradeClinicalIntensiveDatesUnverified',currentNativeTheoryCellExactJoin=True,originalNativeEducationalRecordUnchanged=True,printedReservationMinutesUnmodified=True,actualAttendanceConfirmed=False,knownIndividualClinicalAllocationInOtherCellsNotAppliedToTheory=True,originalFrozenSourceNotes=suffix)
 next(p for p in proof if p['sourceId']==c['sourceId'])['newDatedReservations']=len(dates)
priorMap={c['sourceId']:c for c in previous['courses']};assert all(c==priorMap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in byid)
for c in new['courses']:
 if c['sourceId'] in byid:assert c['sourceEducation']['nativePublicBlock']==priorMap[c['sourceId']]['sourceEducation']['nativePublicBlock']
new.update(candidateRevision='upper-theory-source-semantic-v5',predecessorSHA256=hashlib.sha256(oldBytes).hexdigest(),completionClaim=False)
def put(n,v):(P/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
put('chosun-unknown-2026-2.upper-theory-source-semantic-candidate-v5.json',new)
put('independent-current-20-theory-semantic-proof.json',proof)
put('current-notice-whole-education-operation-receipt.json',dict(sourceURL='https://nurse.chosun.ac.kr/bbs/nurse/694/233477/artclView.do',sourceSHA256=hashlib.sha256(Path('/private/tmp/chosun-nurse-233477-fresh.html').read_bytes()).hexdigest(),sourceUpdatedDate='2026-09-07',educationalBody=body,allCurrentSourcePages=1,currentPDFSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),noTheoryIndividualDateAllocationLiteralInThisNoticeOrOnePage=False if any(k in body for k in ['집중','격주','회전']) else True,clinicalRuleNotAppliedToTheory=True,extraPrivateMetadataSaved=False))
put('candidate-audit.prepared.json',dict(metadataDocumentBlocks=len(new['courses']),priorScheduled=sum(bool(c['schedules']) for c in previous['courses']),priorDates=sum(len(c['schedules']) for c in previous['courses']),newEligible=20,newDates=sum(p['newDatedReservations'] for p in proof),scheduled=sum(bool(c['schedules']) for c in new['courses']),dates=sum(len(c['schedules']) for c in new['courses']),other115CoursesFullDeepUnchanged=True,allOld73ScheduledDeepUnchanged=True,oldCurrentSourceCorrectionsPreserved=True,sourceIdUnionUnchanged=True,completionClaim=False,actualAttendanceConfirmed=False,SDKUsed=False,productChanged=False))
(P/'own-current-calendar-frozen.json').write_bytes((V4/'own-current-calendar-frozen.json').read_bytes())
print(json.loads((P/'candidate-audit.prepared.json').read_text()))
