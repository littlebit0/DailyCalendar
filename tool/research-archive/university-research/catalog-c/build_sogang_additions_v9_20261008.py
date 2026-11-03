"""Five current exact-date plans with unallocated modalities and submissions held."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from sogang_public_education import same_educational_value

ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-v9-20261008'
BASE = ROOT / 'sogang-additions-v8-20261008/sogang-unknown-2026-2.eighty-reviewed-20261008.json'
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
config = [
 ('GKE3009-01',29,'계획서 직접 날짜 일반 강의·발표 28회와 공시·계획서 일치 10/21 중간시험 1회만 반영합니다. 표의 7주가 중간시험이고 8주는 실제 강의 날짜 10/26·28을 명시하므로 주차번호를 표준 학사주차로 바꾸지 않습니다. 15주 12/14·16은 실제 문법 수업 모형 발표이며 정확 날짜·native시각으로 보존합니다. 16주 12/21·23은 기말 보고서로 출석 미확인, 12/23학기밖이므로 모두 보류. 면담 장소 zoom을 강의 모드로 오해하지 않습니다. 강의·발표·장애학생 사전상담과 후속 계획 변경 조건 보존.'),
 ('IIS4104-01',25,'직접 날짜의 교수지도 팀 활동·강의·발표 25회만 반영합니다. 10/5 대체공휴일 제외. 8주 10/19·21 중간 점검과 16주 12/14·16 최종 결과물 제출은 실제 출석 운영 미확인으로 예약 보류. 9주는 10/28 한 날짜만 공개되어 10/26을 생성하지 않습니다. 원문 교양선택(3학점) 보존, broad분류 추정 없음. 2~4학년 대상, 팀별 탐구·유고결석·사전 일정 조율·첫 시간 AI 과제 기준 후속 안내 조건 보존.'),
 ('KLC1015-01',27,'현재 기본 대면 수업과 주차별 대면 운영을 보존해 직접 날짜 일반 수업 27회만 반영합니다. 9/24 추석 휴강 제외. source10/22중간과제 vs current10/20시험 배정 차이와 실제 출석 미확인으로 평가 예약 보류. 12/15기말 콘텐츠 소개 글 완성 실제 출석 미확인 보류. 국제학생 대상 중급한국어, 교실한국어사용·15분초과지각결석·무단퇴실결석·녹음촬영금지 등 조건 보존. 추후 학교방침으로 비대면 전환 시 녹화/실시간일 수 있어 아직 날짜별 변경을 추정하지 않으며 실시간Zoom시카메라/스피커켜기 조건 별도 보존.'),
 ('MGT4105-01',24,'직접 날짜 일반 강의·조별 발표 24회만 반영합니다. 10/5대체공휴일 제외. 7주 10/12·14 특강은 상황에 따라 비대면으로 바뀔 수 있으며 날짜별 확정모드 미공개로 보류합니다. 8주 10/19 기말과제 자율 준비와 날짜 미인쇄 중간고사, 16주 날짜 미인쇄 기말고사는 출석 예약 보류. 2~4학년 대상, 조별 발표 팀별 실제12/2·7·9·14 및 후속진도·평가 변경 조건 보존.'),
 ('MGT4110-01',24,'직접 날짜 일반 강의·조별 발표 24회만 반영합니다. 10/5대체공휴일 제외. 7주 10/12·14 실무자 특강의 대면/비대면 여부 후속 고지로 확정모드 미확인 보류. 8주 10/19 조별 기말과제 준비·토론은 자율 운영인지 실제 교실 출석인지 미확인, 날짜 미인쇄 중간고사와 16주 날짜 미인쇄 기말고사도 예약 보류. 2~4학년 대상, 조별 실제12/2·7·9·14발표·비윤리적행위 평가조건 보존.'),
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
 weekdays={2,4} if key=='KLC1015-01' else {1,3}
 blocks=re.split(r'(\d+)\s*주차',text);meetings=[];holds=[];weeks=[]
 numbers=[int(blocks[i]) for i in range(1,len(blocks),2)]
 assert numbers==(list(range(1,9))+[8]+list(range(9,17)) if key.startswith('MGT') else list(range(1,17))),(key,numbers)
 for i in range(1,len(blocks),2):
  week=int(blocks[i]);body=blocks[i+1];header=body.split('학습목표',1)[0]
  dates=re.findall(r'(\d{1,2})/(\d{1,2})',header)
  assessment=week in (7,16) if key=='GKE3009-01' else week in (8,16)
  if key.startswith('MGT') and week==7:assessment=True
  if not dates:
   assert key.startswith('MGT') and week in (8,16)
  else:assert len(dates) in (1,2),(key,week,header)
  for mo,day in dates:
   date=dt.date(2026,int(mo),int(day));reason=''
   if assessment:reason='assessment/submission or unconfirmed lecture mode/self-directed work; attendance not confirmed'
   elif date.isoformat() in {'2026-09-24','2026-10-05'}:reason='source/national holiday closure'
   assert date.isoweekday() in weekdays,(key,date)
   if reason:holds.append({'date':date.isoformat(),'week':week,'reason':reason});continue
   assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,date)
   m={'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
   if key=='KLC1015-01':m['deliveryMode']='inPerson'
   meetings.append(m)
  weeks.append({'week':week,'printedHeader':header,'printedDates':[dt.date(2026,int(mo),int(day)).isoformat() for mo,day in dates],'sourceOperatingBody':body})
 if key=='GKE3009-01':
  assert row['exam'].startswith('10.21(수)12:00~13:15[J319]')
  assert any(h['date']=='2026-10-21' for h in holds)
  holds=[h for h in holds if h['date']!='2026-10-21']
  meetings.append({'date':'2026-10-21','weekday':3,'startMinute':start,'endMinute':end,'classroom':room})
 if key=='IIS4104-01':
  assert '교양선택(3학점)' in re.sub(r'\s+','',source['sourceHeader']);c['sourceNativeClassification']='교양선택'
 assert len(meetings)==expected,(key,len(meetings),expected)
 assert len({m['date'] for m in meetings})==len(meetings)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':source['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==5
assert sum(bool(c['schedules']) for c in result['courses'])==85
assert sum(len(c['schedules']) for c in result['courses'])==2060
candidate=OUT/'sogang-unknown-2026-2.eighty-five-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':80,'previousPlans':1931,'addedScheduled':5,'addedPlans':129,'scheduled':85,'plans':2060,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('85/2060; 5 new 129 plans')
