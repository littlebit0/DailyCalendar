"""Current printed dates only; first-week modality and split exam rooms held."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
from sogang_public_education import same_educational_value
ROOT=Path(__file__).parent
OUT=ROOT/'sogang-additions-v10-20261008'
BASE=ROOT/'sogang-additions-v9-20261008/sogang-unknown-2026-2.eighty-five-reviewed-20261008.json'
base=json.loads(BASE.read_text());result=copy.deepcopy(base)
config=[('ENG3103-01',28,'직접 날짜 일반 강의·실습·공연·시험준비27회 및 공시·계획서 일치10/26중간시험1회. 10/5휴일,10/21·12/16NoClass 제외,12/21최종시험은 실제clock미공개 보류. 2~4학년 대상, 물리/전자 읽기자료 수업지참과 민감한 내용 사전확인, 후속진도변경 조건 보존.'),('HIS3032-01',24,'계획서 직접 날짜 일반강의·토론23회 및 공시·계획서 일치10/21중간시험1회. 9/18축제 운영미확인,11/20휴강일 제외;10/23다른중간시험·12/16/18기말시험clock미공개 보류. 전체학년 대상, 상황에 따라 특별강의/박물관답사 추가가능하나 실제날짜·시각 미배정 조건 보존.'),('LCU4119-02',26,'교환·방문학생 초급한국어. 첫주9/1·3온라인 방식이 live/녹화중 미확정이므로 보류; 직접 날짜 일반수업·발표25회 및 공시·계획서 일치10/20중간시험1회. 12/15기말시험clock미공개 보류. 원문4주9/22만 배정,9/24추석휴강 생성안함. 조별말하기 발표·공결증빙·장애학생 사전조율 조건 보존.'),('LCU4122-01',26,'교환·방문학생 중급한국어. 첫주9/1·3온라인 방식 live/녹화 미확정으로 보류; 직접 날짜 일반수업·발표25회 및 공시·계획서 일치10/22중간시험1회. 12/17기말시험clock미공개 보류. 4주9/22만 원문배정,추석일 생성안함. 조별발표·공결증빙·장애학생 사전조율 조건 보존.'),('MGT3001-03',27,'2026가을9/1수정 계획서 명시 날짜 일반수업27회. 10/5NoClass 제외;10/21EXAM1은 공시MA202/MA208중 실제개인시험실 배정 미공개로 보류;12/16EXAM2기말시험clock미공개 보류. 날짜미인쇄10/26미생성. 읽기자료·토론·팀활동·시험보충불가·사전후속진도변경 조건 보존. 정규수업실MA202와12:00~13:15 실제clock 일치.')]
proofs=[]
for key,expected,note in config:
 source=json.loads((OUT/f'{key}.source-education.json').read_text());row=source['currentPublicRow'];text=source['weeklyOperatingText']
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and source['currentBytesEqualPrior']
 assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);assert end-start==75
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1];weekdays={2,4} if key.startswith('LCU') else ({3,5} if key.startswith('HIS') else {1,3})
 meetings=[];holds=[];weeks=[]
 if key=='MGT3001-03':
  matches=list(re.finditer(r'(\d{1,2})/(\d{1,2})\s*\(([MW])\)',text));blocks=[(0,text[m.start():(matches[i+1].start() if i+1<len(matches) else len(text))]) for i,m in enumerate(matches)]
 else:
  split=re.split(r'Week\s*(\d+)',text);assert [int(split[i]) for i in range(1,len(split),2)]==list(range(1,17));blocks=[(int(split[i]),split[i+1]) for i in range(1,len(split),2)]
 for week,body in blocks:
  header=body if key in {'ENG3103-01','MGT3001-03'} else body.split('Topics',1)[0].split('Learning Objectives',1)[0]
  dates=re.findall(r'(\d{1,2})/(\d{1,2})',header);assert dates,(key,week)
  for mo,day in dates:
   date=dt.date(2026,int(mo),int(day));ds=date.isoformat();reason=''
   if key=='ENG3103-01' and ('No Class' in body[body.find(f'[{mo}/{day}]'):body.find(f'[{mo}/{day}]')+35] or ds=='2026-12-21'):reason='source No Class or final exam clock unpublished'
   if key=='HIS3032-01' and (week in (8,16) or ds in {'2026-09-18','2026-11-20'}):reason='assessment clock unpublished or festival/college closure operating condition unconfirmed'
   if key.startswith('LCU') and week in (1,8,16):reason='first-week online modality unallocated or assessment clock unpublished'
   if key=='MGT3001-03' and ('No Class' in body or 'EXAM #' in body):reason='source No Class or split exam rooms/final exam clock unpublished'
   assert date.isoweekday() in weekdays,(key,ds)
   if reason:holds.append({'date':ds,'week':week,'reason':reason});continue
   assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21)
   meetings.append({'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
  weeks.append({'week':week,'printedHeader':header,'printedDates':[dt.date(2026,int(m),int(d)).isoformat() for m,d in dates],'sourceOperatingBody':body})
 if key in {'HIS3032-01','LCU4119-02','LCU4122-01'}:
  mid={'HIS3032-01':'2026-10-21','LCU4119-02':'2026-10-20','LCU4122-01':'2026-10-22'}[key];date=dt.date.fromisoformat(mid)
  exam=re.fullmatch(r'(\d+)\.(\d+)\([월화수목금]\)(\d\d):(\d\d)~(\d\d):(\d\d)\[([^\]]+)\]',row['exam']);assert exam and int(exam[1])==date.month and int(exam[2])==date.day and int(exam[3])*60+int(exam[4])==start and int(exam[5])*60+int(exam[6])==end and exam[7]==room
  assert any(h['date']==mid for h in holds);holds=[h for h in holds if h['date']!=mid];meetings.append({'date':mid,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
 if key=='ENG3103-01':assert row['exam']=='10.26(월)16:30~17:45[J327]'
 assert len(meetings)==expected,(key,len(meetings),expected);assert len({m['date'] for m in meetings})==expected;meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':expected,'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':source['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':expected,'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b];assert len(changed)==5
assert sum(bool(c['schedules']) for c in result['courses'])==90;assert sum(len(c['schedules']) for c in result['courses'])==2191
candidate=OUT/'sogang-unknown-2026-2.ninety-reviewed-20261008.json';candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':85,'previousPlans':2060,'addedScheduled':5,'addedPlans':131,'scheduled':90,'plans':2191,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print('90/2191; 5 new 131 plans')
