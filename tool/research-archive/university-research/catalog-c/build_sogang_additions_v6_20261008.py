"""Five public plans with exact dates; source anomalies are held, never corrected."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from sogang_public_education import same_educational_value

ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-v6-20261008'
BASE = ROOT / 'sogang-additions-v5-20261008/sogang-unknown-2026-2.sixty-six-reviewed-20261008.json'
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
config = [
 ('ENG3303-01',27,'실제 주차별 일반 수업 27회만 반영합니다. 계획서가 8·16주 시험기간 no class를 명시하므로 공시 중간시험 정보를 일반 강의로 생성하지 않습니다. 실제 시험 배정·시각 미확인 보류. 언어학 선행 과목을 이수한 4학기 이상 학부생 대상, 한국어 수업. 9/24 전국 휴일 제외; 후속 강의계획 변경 확인 필요.'),
 ('GME3003-01',27,'직접 날짜와 대면 수업 방법이 있는 일반 강의 27회만 반영합니다. 시험 주차는 세부 범위를 후속 공지하지만 실제 날짜를 인쇄하지 않아 시험 예약을 보류합니다. 9/24 휴일 제외. 과제에 남아 있는 4월24일 사이버캠퍼스 토론 마감은 현재 학기 밖이므로 날짜를 고치거나 출석으로 생성하지 않습니다. 자료·평가는 후속 공지에 따라 변경될 수 있습니다.'),
 ('GME4014-01',24,'계획서 명시 강의실 실시간 대면 운영을 보존합니다. 실제 일반 수업 24회만 반영합니다. 9/10 개강미사 및 9/24 추석 휴강을 제외하고, 15주차에 인쇄된 6/9·6/11은 학기 밖이므로 12월로 고치지 않습니다. 시험 주차의 실제 날짜 미공개로 예약을 보류합니다. 팀별 토론·발표도 교실 수업에 포함하되 발표 날짜는 수강생 수에 따라 변경될 수 있습니다.'),
 ('MAE4004-01',27,'계획서의 강의실 대면 중심 운영과 일반 수업 27회만 반영합니다. 9/24 휴일 제외. 중간·기말 대면 지필고사라는 평가 방식은 보존하되 주차 표에 실제 날짜가 없으므로 시험 예약은 보류합니다. 2~4학년 대상. 팀 발표·진도·일정의 후속 변경 확인 필요.'),
 ('MAE4023-01',26,'계획서가 직접 인쇄한 일반 강의·워크숍·실습·발표 26회만 반영합니다. 4주는 9/22 한 날짜만 공개되어 9/24 수업을 만들지 않습니다. 9주차 두 번째 날짜 10/19는 월요일로 공시 화·목 및 해당 주차와 충돌하므로 보류하며 10/29로 고치지 않습니다. 8·16주는 연출 초안·기말 에세이 제출이며 실제 출석 운영이 확인되지 않아 예약을 보류합니다. 조별 발표 방법·과제 상세는 추후 공지, 2~4학년 대상.'),
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
 # Split only actual weekly table headers, never topic/assignment mentions.
 pattern=r'Week\s+(\d+)\s*:' if key.startswith('ENG') else r'(\d+)\s*주차\s*\('
 blocks=re.split(pattern,text);meetings=[];holds=[];weeks=[]
 assert [int(blocks[i]) for i in range(1,len(blocks),2)]==list(range(1,17))
 for i in range(1,len(blocks),2):
  week=int(blocks[i]);body=blocks[i+1]
  header=body.split(':',1)[0] if key.startswith('ENG') else body.split('학습목표',1)[0]
  # Whitespace normalization is limited to the date header, not the topic body.
  dates=re.findall(r'(\d{1,2})/(\d{1,2})',re.sub(r'\s+','',header))
  if week in (8,16):
   for mo,day in dates: holds.append({'date':dt.date(2026,int(mo),int(day)).isoformat(),'week':week,'reason':'assessment submission or no regular class; physical attendance not confirmed'})
   weeks.append({'week':week,'printedHeader':header,'sourceOperatingBody':body,'reason':'assessment or explicitly no class; no date inference'})
   continue
  assert len(dates) in (1,2),(key,week,header)
  for mo,day in dates:
   date=dt.date(2026,int(mo),int(day));reason=''
   if not dt.date(2026,9,1)<=date<=dt.date(2026,12,21): reason='source date outside actual fall term; no month correction'
   elif date.isoweekday() not in (2,4): reason='source weekday conflicts native offering clock; no date correction'
   elif date.isoformat()=='2026-09-24': reason='national holiday / source Chuseok closure'
   elif key=='GME4014-01' and date.isoformat()=='2026-09-10': reason='source explicit opening Mass no class'
   if reason:
    holds.append({'date':date.isoformat(),'week':week,'reason':reason});continue
   m={'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
   if key.startswith('GME') or key=='MAE4004-01':m['deliveryMode']='inPerson'
   meetings.append(m)
  weeks.append({'week':week,'printedHeader':header,'printedDates':[dt.date(2026,int(mo),int(day)).isoformat() for mo,day in dates],'sourceOperatingBody':body})
 assert len(meetings)==expected,(key,len(meetings),expected)
 assert len({m['date'] for m in meetings})==len(meetings)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':source['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==5
assert sum(bool(c['schedules']) for c in result['courses'])==71
assert sum(len(c['schedules']) for c in result['courses'])==1723
candidate=OUT/'sogang-unknown-2026-2.seventy-one-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':66,'previousPlans':1592,'addedScheduled':5,'addedPlans':131,'scheduled':71,'plans':1723,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('71/1723; 5 new 131 plans')
