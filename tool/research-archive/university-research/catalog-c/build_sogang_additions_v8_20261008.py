"""Four exact public plans, including a directly published makeup lecture."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from sogang_public_education import same_educational_value

ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-v8-20261008'
BASE = ROOT / 'sogang-additions-v7-20261008/sogang-unknown-2026-2.seventy-six-reviewed-20261008.json'
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
config = [
 ('GMT3003-01',28,'실제 일반 수업 27회와 현재 공시·계획서 일치 10/21 대면 중간시험 1회를 반영합니다. 10/5 대체공휴일 제외. 12/16·21 기말 대면시험 실제 배정·시각 미확인 보류. 수업·과제 문의 한국어, 수업 방해 1회 경고 후 반복 시 1점 감점 및 후속 세부 공지 조건 보존.'),
 ('HISQ983-01',22,'직접 날짜의 일반 강의·실습·수업시연 22회만 반영합니다. 9/10 개강미사 안내·9/24 추석 제외/보류. 5주 9/29·10/1 온라인 자료 업로드는 실시간/VOD·실제 출석 미확인, 11주 11/10·12 박물관 답사 실제 집합 시각·상세 장소 미확인으로 교실 예약 없음. 평가표 중간고사 값 없음과 주차표·공시 시험 안내의 충돌로 8주 시험 예약 보류. 16주 포트폴리오 제출/프로젝트 마무리 실제 평가 출석 미확인 보류. 3~4학년 대상·팀티칭·절대평가 및 세부 과제 기준 후속 공지 보존.'),
 ('ENG3510-01',21,'확인된 일반 교실 수업 20회와 계획서가 명시한 10/21 10/7 보강 수업 1회만 반영합니다. 9/9 No class 녹화 백업은 공개 영상의 별도 시각·출석 조건 미확인으로 정규 시각 수업 없음. 9/18 축제 미확인, 9/25 추석, 10/7·9 학회/휴일, 10/23 No class 중간, 10/28 학회, 11/20 수시 휴강 제외/보류. 5주 10/1 목요일은 native 수·금과 충돌하여 10/2로 고치지 않음. 기말 실제 시험 배정·시각 미확인. 12/9·11 발표 및 동료평가 참석 필수, 미참석 시 발표·프로젝트 0점. 영문/인문 학생 중심이며 공학·AI·CS·전기·코딩 경험자는 고급 과목 권장 및 본 과목 수강 희망 시 사전 교수 면담 승인 필요. 유료 AI 도구 구독 권장이나 의무 아님; 무료 사용의 제한은 성적 조정 사유가 아니며 동일 평가 기준 적용.'),
 ('MGT3002-03',27,'현재 공개 native2026-2에 배정된 계획서의 직접 날짜 일반 수업 26회와 계획서·공시 일치 10/20 중간시험 1회만 반영합니다. 원문 헤더 학기2와 actual공개학기·월일·요일 별도 확인. 9/10 개강미사·9/24 추석 휴강 제외. 중간 나머지 슬롯10/22 및 기말12/15 실제 평가 시각 미확인 보류. 2~4학년 대상, 팀 발표·리포트·사이버캠퍼스 후속 공지 조건 보존.'),
]
proofs=[]
for key,expected,note in config:
 source=json.loads((OUT/f'{key}.source-education.json').read_text())
 row=source['currentPublicRow'];text=source['weeklyOperatingText']
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and source['currentBytesEqualPrior']
 assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText'])
 start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);assert end-start==75
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1]
 weekdays={1,3} if key=='GMT3003-01' else {3,5} if key=='ENG3510-01' else {2,4}
 pattern=r'Week\s+(\d+)\b' if key=='ENG3510-01' else r'(\d+)\s*주차'
 blocks=re.split(pattern,text);meetings=[];holds=[];weeks=[]
 assert [int(blocks[i]) for i in range(1,len(blocks),2)]==list(range(1,17))
 for i in range(1,len(blocks),2):
  week=int(blocks[i]);body=blocks[i+1]
  # Dates in split PDF columns may follow the learning-objective text;
  # only actual table dates are retained, with assessment weeks handled separately.
  if key=='ENG3510-01':
   header=body.split('Learning Objectives',1)[0]
   normalized=re.sub(r'Sep\s+(\d+)',r'9/\1',header)
   normalized=re.sub(r'Nov\s+(\d+)',r'11/\1',normalized)
   dates=re.findall(r'(\d{1,2})/(\d{1,2})',normalized)
  else:
   header=body
   dates=re.findall(r'(\d{1,2})/(\d{1,2})',body)[:2]
  assert len(dates)==2,(key,week,dates)
  for mo,day in dates:
   date=dt.date(2026,int(mo),int(day));reason=''
   if week in (8,16) and not (key=='ENG3510-01' and date==dt.date(2026,10,21)):
    reason='assessment allocation/date-clock or physical attendance not confirmed'
   elif date.isoweekday() not in weekdays:reason='source weekday conflicts native clock; no correction'
   elif date.isoformat() in {'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}:reason='source/national holiday or school explicit closure'
   elif key in {'HISQ983-01','MGT3002-03'} and date.isoformat()=='2026-09-10':reason='source opening Mass no class/regular operating unconfirmed'
   elif key=='HISQ983-01' and week in (5,11):reason='online materials or museum field work: actual dated mode/time/place unconfirmed'
   elif key=='ENG3510-01' and date.isoformat() in {'2026-09-09','2026-09-18','2026-10-07','2026-10-28'}:reason='source no class/conference or festival unconfirmed; undated recording not scheduled'
   assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21)
   if reason:holds.append({'date':date.isoformat(),'week':week,'reason':reason});continue
   meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
  weeks.append({'week':week,'printedHeader':header,'printedDates':[dt.date(2026,int(mo),int(day)).isoformat() for mo,day in dates],'sourceOperatingBody':body})
 if key in {'GMT3003-01','MGT3002-03'}:
  m=re.search(r'(\d{2})\.(\d{2})\(',row['exam']);date=dt.date(2026,int(m[1]),int(m[2]));assert any(h['date']==date.isoformat() for h in holds)
  holds=[h for h in holds if h['date']!=date.isoformat()]
  meeting={'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  if key=='GMT3003-01':meeting['deliveryMode']='inPerson'
  meetings.append(meeting)
 if key=='ENG3510-01':assert '10/21 – in class (10/7 backup class)' in text
 assert len(meetings)==expected,(key,len(meetings),expected)
 assert len({m['date'] for m in meetings})==len(meetings)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':source['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==4
assert sum(bool(c['schedules']) for c in result['courses'])==80
assert sum(len(c['schedules']) for c in result['courses'])==1931
candidate=OUT/'sogang-unknown-2026-2.eighty-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':76,'previousPlans':1833,'addedScheduled':4,'addedPlans':98,'scheduled':80,'plans':1931,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False,'deferredReview':[{'offering':'CHU4024-01','reason':'native CHU4024 vs source header CHU4003; identity conflict'}, {'offering':'MGT4106-02','reason':'source 10percent online learning not allocated to actual dates; exam has two rooms individual allocation unpublished'}]}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('80/1931; 4 new 98 plans')
