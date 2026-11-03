"""Five separately reviewed public plans; field work and conflicting assessments held."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from sogang_public_education import same_educational_value

ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-v7-20261008'
BASE = ROOT / 'sogang-additions-v6-20261008/sogang-unknown-2026-2.seventy-one-reviewed-20261008.json'
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
config = [
 ('HSS3013-01',28,'현재 2026-2 계획서의 직접 날짜 일반 수업 27회와 공시·계획서 일치 10/26 중간시험 1회만 반영합니다. 원문은 수요일과 다음 월요일 날짜를 같은 주차에 묶으므로 날짜를 표준 주차로 옮기지 않습니다. 10/5 휴일 제외. 12/16·21 기말 실제 배정·시각 미확인 보류. 1~4학년 대상, 강의·조별 토의·에세이 평가 및 조 편성·진도 변경 조건 보존.'),
 ('HFU4008-01',27,'현재 2026-2 공개 강좌에 배정된 실제 계획서의 일반 수업 27회만 반영합니다. 문서 헤더는 학기2만 인쇄하지만 현재 native 조회 학기와 인쇄 날짜의 요일을 각각 확인합니다. 서강문화제 기간 정상 수업 직접 안내, 9/24 수업 없음. 중간은 시험기간 범위만 공개되고 기말은 학기말 조별 발표로 대체하므로 실제 평가 출석·시각 미확인 보류. 한국어, 전학년, 선행 특정과목 없음. 최종 수강인원에 따라 운영·평가 변경 가능하며 후속 공지 확인 필요.'),
 ('ENG3010-01',24,'현재 2026-2 native 강좌의 실제 계획서 일반 수업 24회만 반영합니다. 계획서 교실 tbd와 현재 공시 J215를 구분합니다. PDF 헤더 별도 연도 미인쇄이나 현재 native 공개 버튼 배정 및 실제 월일·요일 일치 확인. 9/18 축제 운영 미확인, 9/25·10/9 source No Class 및 휴일, 11/20 학교 스터디데이 휴강 제외/보류. 주차 표 중간·기말 실제 날짜 미인쇄로 시험 예약 없음. 2~4학년 대상, 4회 초과 결석 FA 및 참여·진도 변경 조건 보존.'),
 ('HSS3023-01',7,'주차별 이론강의(1~3주), 프로젝트 기획 워크숍(4~5주), 11주 중간 회고·발표, 15주 최종 회고·발표 총 7회만 공시 수요일13:30~16:15 교실 범위로 보존합니다. 6~7·9~10·12~14주 On-Site 팀 프로젝트·현장 활동의 실제 날짜별 집합 시각·장소 미확인으로 교실 예약 생성 없음. 8·16주 시험 주차 실제 평가 출석 미확인 보류. 12/19(금) 성찰문 제출 요일은 2026 토요일과 충돌하므로 자동 교정·출석 생성 없음. 원문 교양자유선택(3학점) 보존, broad분류 추정 없음. 1~4학년40명, 조 최대5명, 결석3회이상 FA·협업일지·별도 선발조건 보존.'),
 ('HFS2003-01',24,'원문 명시 기본 대면 강의의 일반 수업 24회만 반영합니다. 중간고사를 개별과제로 대체한다는 평가표와 중간고사 주차·현재 공시 시험 정보가 충돌하므로 실제 시험 예약은 보류합니다. 9/18 축제 운영 미확인, 9/25·10/9 휴일, 11/20 학교 스터디데이 휴강 제외/보류. 기말 실제 배정·시각 미확인 보류. 그룹 나눔 또는 세인트 토론방 작성은 강의 구성 안내이며 수강 모드 VOD로 추정하지 않습니다. 전학년 대상, 절대평가·에세이4~5회·지각 제출 감점 조건 보존.'),
]
proofs=[]
for key,expected,note in config:
 source=json.loads((OUT/f'{key}.source-education.json').read_text())
 row=source['currentPublicRow'];text=source['weeklyOperatingText']
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and source['currentBytesEqualPrior']
 assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText'])
 start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4])
 assert end-start==(165 if key=='HSS3023-01' else 75)
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1]
 weekdays={1,3} if key=='HSS3013-01' else {2,4} if key=='HFU4008-01' else {3} if key=='HSS3023-01' else {3,5}
 meetings=[];holds=[];weeks=[]
 if key=='ENG3010-01':
  entries=list(re.finditer(r'(?<!\d)(\d{1,2})/(\d{1,2})\s+Topic',text))
  for i,m in enumerate(entries):
   date=dt.date(2026,int(m[1]),int(m[2]));body=text[m.end():entries[i+1].start() if i+1<len(entries) else len(text)]
   reason='source No Class/national holiday/school closure or festival operation unconfirmed' if date.isoformat() in {'2026-09-18','2026-09-25','2026-10-09','2026-11-20'} else ''
   if reason:holds.append({'date':date.isoformat(),'reason':reason})
   else:meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
   weeks.append({'printedDates':[date.isoformat()],'sourceOperatingBody':body})
 else:
  pattern=r'주차\s*(\d+)\s*\(' if key=='HSS3013-01' else r'주차\s*(\d+)\b' if key=='HFU4008-01' else r'(\d+)\s*주차'
  blocks=re.split(pattern,text)
  # HFS repeats week 1 for separate meetings; preserve the native table structure.
  numbers=[int(blocks[i]) for i in range(1,len(blocks),2)]
  assert numbers==([1,1]+list(range(2,17)) if key=='HFS2003-01' else list(range(1,17))),(key,numbers)
  for i in range(1,len(blocks),2):
   week=int(blocks[i]);body=blocks[i+1];header=body.split('학습목표',1)[0]
   if week in (8,16):
    weeks.append({'week':week,'printedHeader':header,'sourceOperatingBody':body,'reason':'assessment allocation or assignment attendance unknown'})
    continue
   if key=='HSS3013-01':
    h=re.sub(r'\s+','',header);mo,day=re.search(r'(\d{1,2})/(\d{1,2})',h).groups();tail=h[h.index(',')+1:].split(')')[0]
    dates=[(mo,day),tuple(tail.split('/')) if '/' in tail else (mo,tail)]
   elif key=='HFS2003-01':
    dates=[];month=None
    for m in re.finditer(r'(?:(\d{1,2})/)?(\d{1,2})\s*\([수금]\)',header):
     month=m[1] or month;assert month;dates.append((month,m[2]))
   else:dates=re.findall(r'(\d{1,2})/(\d{1,2})',header)
   assert len(dates)==(1 if key=='HSS3023-01' or key=='HFS2003-01' and week==1 else 2),(key,week,header)
   for mo,day in dates:
    date=dt.date(2026,int(mo),int(day));reason=''
    assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21) and date.isoweekday() in weekdays,(key,date)
    if key=='HSS3023-01' and week not in {1,2,3,4,5,11,15}:reason='On-Site team field work; native classroom attendance/time not confirmed'
    elif date.isoformat() in {'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}:reason='national holiday or school explicit study-day closure'
    elif key=='HFS2003-01' and date.isoformat()=='2026-09-18':reason='festival operation unconfirmed'
    if reason:holds.append({'date':date.isoformat(),'week':week,'reason':reason});continue
    m={'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
    if key=='HFS2003-01':m['deliveryMode']='inPerson'
    meetings.append(m)
   weeks.append({'week':week,'printedHeader':header,'printedDates':[dt.date(2026,int(mo),int(day)).isoformat() for mo,day in dates],'sourceOperatingBody':body})
 if key=='HSS3013-01':
  assert '10/21,26' in re.sub(r'\s+','',text)
  assert row['exam'].startswith('10.26(월)16:30~17:45[AS303]')
  meetings.append({'date':'2026-10-26','weekday':1,'startMinute':start,'endMinute':end,'classroom':room})
 if key=='HSS3023-01':
  assert '교양자유선택(3학점)' in re.sub(r'\s+','',source['sourceHeader']);c['sourceNativeClassification']='교양 자유선택'
 assert len(meetings)==expected,(key,len(meetings),expected)
 assert len({m['date'] for m in meetings})==len(meetings)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':source['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==5
assert sum(bool(c['schedules']) for c in result['courses'])==76
assert sum(len(c['schedules']) for c in result['courses'])==1833
candidate=OUT/'sogang-unknown-2026-2.seventy-six-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':71,'previousPlans':1723,'addedScheduled':5,'addedPlans':110,'scheduled':76,'plans':1833,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False,'deferredReview':[{'offering':'HFS2002-01/HFU4023-02','reason':'2026-2 heading but native inner metadata semester 1; held without choosing source priority'}]}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('76/1833; 5 new 110 plans')
