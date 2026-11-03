# coding: utf-8
import copy, json, hashlib, datetime
from pathlib import Path
import pdfplumber
b=Path(__file__).parent
root=Path('work/university-research')
prior=root/'catalog-c/ut-current-own-regular-planned-dates-v6-20261009/ut-unknown-2026-2.current-own-regular-planned-v6.json'
pdf=root/'root-ut-current-electri-visual-review-20261009/current-2026-2-electri.pdf'
rule=root/'catalog-c/ut-current-own-regular-term-rule-proof-v5-20261009/independent-current-own-regular-term-rule-education-proof.json'
cal=root/'catalog-c/ut-current-20261008/calendar-educational-dates.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(pdf)=='1609eae5a48fa784614ab188a12cfc35336f9903dacf59ee4d00d62fc4d28f9a'
old=json.loads(prior.read_text());candidate=copy.deepcopy(old)
p=pdfplumber.open(pdf).pages[0];t=p.find_tables()[0];v=t.extract()
starts=[38,41,44,47,50,53]
clock={1:('18:30~19:20',1110,1160),2:('19:25~20:15',1165,1215),3:('20:20~21:10',1220,1270),4:('21:15~22:05',1275,1325),5:('22:10~23:00',1330,1380),6:('23:05~23:55',1385,1435)}
axes=[]
for n,r in enumerate(starts,1):
 y0=t.rows[r].cells[1][1];y1=t.rows[r+2].cells[1][3]
 box=(77.3,y0+.15,110.8,y1-.15);text=p.crop(box).extract_text();assert clock[n][0] in text
 axes.append({'nativeNightPeriod':n,'exactClockText':text,'boundingBox':box,'startMinute':clock[n][1],'endMinute':clock[n][2]})
# Literal independently read PDF cell bindings; rows are title, then professor/room (Friday reversed).
blocks=[(6,1,[1,2,3],'디지털제어시스템','김일송','202',39,40),(11,1,[1,2,3],'전력전자실험','이귀준','214',39,40),(11,4,[4,5,6],'전기기기실험','박유섭','314',48,49),(16,1,[1,2,3],'전력전송공학','지평식','202',39,40),(16,4,[4,5],'전동력응용','지평식','202',48,49),(21,1,[1,2,3],'신호처리공학','김영우','202',39,40),(25,1,[1,2,3],'전자기학II','이대종','202',40,39),(25,4,[4,5,6],'회로이론II','이종필','202',49,48),(27,4,[4,5,6],'캡스돈디자인II','이대종','214',48,49)]
literal={1:'2026-09-07 2026-09-14 2026-09-21 2026-09-28 2026-10-12 2026-10-19 2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30 2026-12-07'.split(),2:'2026-09-01 2026-09-08 2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01'.split(),3:'2026-09-02 2026-09-09 2026-09-16 2026-09-23 2026-09-30 2026-10-07 2026-10-14 2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02'.split(),4:'2026-09-03 2026-09-10 2026-09-17 2026-10-01 2026-10-08 2026-10-15 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03'.split(),5:'2026-09-04 2026-09-11 2026-09-18 2026-10-02 2026-10-16 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04'.split()}
# Friday first range has five dates: Sep25/Oct9 holidays. Its prior v6 has same five, hence total correction computed below.
proofs=[]
for col,first,periods,title,prof,room,pr,rr in blocks:
 rowindex=starts[first-1];day=(col-4)//5+1;grade=(col-4)%5+1
 assert grade<=4 and ''.join(v[rowindex][col].split())==title and v[pr][col]==prof and v[rr][col]==room
 for n in periods[1:]:assert v[starts[n-1]][col]=='〃'
 if col==16 and first==4:assert not v[53][col]
 endrow=starts[periods[-1]-1]+2;x0,_,x1,_=t.rows[3].cells[col];box=(x0+.15,t.rows[rowindex].cells[col][1]+.15,x1-.15,t.rows[endrow].cells[col][3]-.15)
 rawtext=p.crop(box).extract_text()
 owncells=[{'row':r,'column':col,'bbox':t.rows[r].cells[col],'text':v[r][col]} for r in range(rowindex,endrow+1)]
 olddates=sorted({s['date'] for c in old['courses'] for s in c['schedules'] if s['weekday']==day});assert olddates==literal[day],(day,olddates,literal[day])
 c=copy.deepcopy(next(c for c in old['courses'] if '290793' in c['sourceId']))
 c.update(sourceId=f'ut-document290793-p1-night{first}-c{col}',courseName=title,professor=prof,departments=[f'전기공학과 {grade}학년'],nativeStudyColumn=str(grade),sourceClassroom=room,sourceSchedule=f'{day}요일 정시제 50분제 '+','.join(str(n) for n in periods),remarks='2026-2 전기공학과 학부 정시제 열의 공개 정규 예약 계획. 원문 제목·교수·실·학년과 동일 열의 반복기호 및 야간 50분제 직접 시작·종료를 대조했습니다. 교시 사이 휴식은 포함하지 않으며 색상으로 수업방식을 추정하지 않고 사용자 선택을 유지합니다. 공식 과목코드·분반·학점·이수구분 미게시이며 내부 문서 위치는 공식 식별자가 아닙니다. 동일 제목 블록을 임의 병합하지 않았습니다. 강의실 숫자는 원문 그대로, 물리 캠퍼스·건물은 미확인입니다. 9/1~10/19 및10/27~12/7 정규 계획 범위이며 중간시험 권장기간·지정보강·기말 구간은 보수적으로 제외합니다. 12/7은 게시 종강일이 아닌 보강 시작 전 경계입니다. 개별 집중 승인·실험 운영 변경·실제 출석·시험·최신 전체 폐강은 미확인입니다. 수강지도 교수 승인 및 타학과·타학년·정원 조건은 개설학과 확인 필요.',sourceEducationCell={'page':1,'nativeColumnIndex':col,'nativeWeekday':day,'nativeStudyColumn':str(grade),'nativeProgramLabel':'정시제','native50Periods':periods,'educationalBlockText':rawtext,'exactPDFBoundingBox':box,'originalEducationalCells':owncells,'titleLiteralPreserved':True,'nativeCodePublished':False,'nativeSectionPublished':False,'clockScope':'current2026-2 electri own undergraduate night50 only','modeInferredFromColor':False,'physicalCampusVerified':False},schedules=[])
 for date in literal[day]:
  for n in periods:c['schedules'].append({'date':date,'weekday':day,'startMinute':clock[n][1],'endMinute':clock[n][2],'classroom':room,'sourcePage':1,'sourceColumn':col,'nativeNightPeriod':n,'reservationRangeOnly':True})
 candidate['courses'].append(c)
 proofs.append({'sourceId':c['sourceId'],'literalTitle':title,'literalProfessor':prof,'literalClassroom':room,'professorRow':pr,'classroomRow':rr,'nativeWeekday':day,'nativeStudyGrade':grade,'nativeColumnIndex':col,'nativeNightPeriods':periods,'originalEducationalCells':owncells,'exactPDFBoundingBox':box,'wholeOriginalBlockText':rawtext,'literalDates':literal[day],'expectedMeetings':c['schedules']})
assert candidate['courses'][:61]==old['courses'];assert len(candidate['courses'])==70
newcount=sum(len(x['expectedMeetings']) for x in proofs);total=sum(len(c['schedules']) for c in candidate['courses'])
candidate['candidateRevision']='current-own-undergraduate-night50-v8'
def save(n,d):(b/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
save('ut-unknown-2026-2.current-night-own-50-v8.json',candidate)
save('prior-v6-frozen-61-761-baseline.json',old)
save('independent-night-50-native-axis-and-literal-dates-proof.json',{'sourceOnly':True,'completionClaim':False,'SDKUsed':False,'priorReferences':61,'priorAppointments':761,'additionalDocumentBlocks':9,'additionalAppointments':newcount,'totalDocumentReferences':70,'totalAppointments':total,'literalDatesByWeekday':literal,'night50Axis':axes,'sourceInputsSHA256':{str(x):sha(x) for x in [prior,pdf,rule,cal]},'proofs':proofs,'excludedNightCells':[{'column':16,'period':6,'reason':'actual empty cell, no ditto; not expanded'},{'column':21,'periods':[4,5,6],'reason':'actual empty cells, not expanded'}],'priorV3ScopeCorrection':'Tuesday night actual UG column11; previous bounded col10 is empty and did not create appointments. Old frozen receipt unchanged.','titlePreservation':'캡스돈디자인II is literal PDF print; no guessed correction to 캡스톤.','regularRuleScope':'current rule66 night/experimental continuous exception plus current2026-2 own weekly chart; planned reservations only, no actual attendance/intensive approval claim','purePythonValidation':'PASS'})
print(len(candidate['courses']),newcount,total)
