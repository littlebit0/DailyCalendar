"""Six further individual current plans; no section/date/campus inference."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
from sogang_public_education import same_educational_value
ROOT=Path(__file__).parent
OUT=ROOT/'sogang-additions-v4-20261008'
BASE=ROOT/'sogang-additions-v3-20261008/sogang-unknown-2026-2.fifty-three-reviewed-20261008.json'
base=json.loads(BASE.read_text());result=copy.deepcopy(base);proofs=[]
for key,heldweeks,expected,notice in [
 ('GKE3035-01',{8,16},24,'국제학생 대상. 9/18 축제기간 운영 미확인 보류, 9/25·10/9 공휴일과 학교 11/20 스터디데이 휴강 제외. 중간·기말은 시험기간 두 날짜만 표기되어 정확 배정 시각 미확인 보류.'),
 ('GKE3036-01',{8,16},24,'국제학생 대상. 9/18 축제기간 운영 미확인 보류, 9/25·10/9 공휴일과 학교 11/20 스터디데이 휴강 제외. 중간·기말은 시험기간 두 날짜만 표기되어 정확 배정 시각 미확인 보류.'),
 ('JAS4003-01',{8,16},27,'9/24 공휴일 제외. 중간·기말 지필시험과 과제는 시험기간 날짜만 표기되어 실제 시험 배정 시각 미확인 보류. 매체문화사 강의 계획과 문헌은 변경될 수 있으며 개인 면담은 별도 일정 조율.'),
 ('LED3010-01',{8,16},27,'공개 계획서 구분은 교양 자유선택(3학점)이며 원문 분류를 보존합니다. 10/5 휴일 제외. 중간·기말 발표 및 발표 평가·피드백은 게시된 교실 수업 계획으로 보존하며 8·16주 시험기간은 생성하지 않습니다. FA 출결 규정과 발표주제 수업 시간 안내·후속 변경 확인.'),
 ('MAE4032-01',{8,16},27,'9/24 공휴일 제외. 중간·기말은 실제 시험 배정 날짜·시각 미확인 보류. 3·4학년 수강대상. 발표 일정은 수강인원에 따라 변경될 수 있음.')]:
 p=OUT/f'{key}.source-education.json';s=json.loads(p.read_text());row=s['currentPublicRow'];t=s['weeklyOperatingText'];compact=re.sub(r'\s+','',t)
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 assert s['currentBytesEqualPrior'] and c['courseCode'] in s['sourceHeader']
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);assert end-start==75
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1]
 weekdays={1,3} if key.startswith('LED') else {3,5} if key.startswith('GKE') else {2,4}
 blocks=re.split(r'Week\s+(\d+)' if key.startswith('MGT') else r'(\d+)\s*주차',t)
 meetings=[];sourceweeks=[];holds=[]
 for i in range(1,len(blocks),2):
  week=int(blocks[i]);body=blocks[i+1];clean=re.sub(r'\s+','',body)
  if key.startswith('MGT'):
   header=body.split('Topics',1)[1].split('Class Work',1)[0] if 'Topics' in body else ''
   printed=re.findall(r'(\d{1,2})/(\d{1,2})\s*\((?:Tues|Thurs)\)',header)
  else:
   printed=re.findall(r'(\d{1,2})/(\d{1,2})',body)[:2]
  assert len(printed)==2,(key,week,printed)
  dates=[dt.date(2026,int(m),int(d)) for m,d in printed]
  assert all(d.isoweekday() in weekdays for d in dates),(key,week,dates)
  if week in heldweeks:
   holds.append({'week':week,'dates':[d.isoformat() for d in dates],'sourceOperatingBody':body});continue
  for d in dates:
   date=d.isoformat()
   if date in {'2026-10-05','2026-09-24'} or (key.startswith('GKE') and date in {'2026-09-18','2026-09-25','2026-10-09','2026-11-20'}):
    holds.append({'date':date,'reason':'source holiday/no class/recorded makeup'});continue
   meetings.append({'date':date,'weekday':d.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
  sourceweeks.append({'week':week,'printedDates':[d.isoformat() for d in dates],'sourceOperatingBody':body})
 if key.startswith('MGT'):
  assert row['exam']=='10.20(화)12:00~13:15[MA202]' and '10/20 (Tues) Midterm Exam' in t
  meetings.append({'date':'2026-10-20','weekday':2,'startMinute':start,'endMinute':end,'classroom':room})
 assert len(meetings)==expected,(key,len(meetings),expected)
 meetings.sort(key=lambda m:m['date'])
 if key=='LED3010-01':
  assert '교양자유선택(3학점)' in re.sub(r'[\s\x00]+','',s['sourceHeader'])
  c['sourceNativeClassification']='교양 자유선택'
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:
  c['departmentRemarks'][dep]+='\n현재 해당 분반의 공개 계획서와 공시 시간표에서 확인되는 날짜별 정규 계획만 반영합니다. '+notice+' 확인 안 된 방식·캠퍼스·실제 출석을 추정하지 않습니다. 이후 운영 변경 공지를 확인하세요.'
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'sourceWeeks':sourceweeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==5 and set(changed)=={p['offering'] for p in proofs}
assert sum(bool(c['schedules']) for c in result['courses'])==58
assert sum(len(c['schedules']) for c in result['courses'])==1386
candidate=OUT/'sogang-unknown-2026-2.fifty-eight-reviewed-20261008.json';candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':53,'previousPlans':1257,'addedScheduled':5,'addedPlans':129,'scheduled':58,'plans':1386,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'closureLimit':'Protected final cancellation detail remains unread; current public offerings present, whole reflection unproven.','deferredIdentityConflicts':[{'offering':'COR1012-02','reason':'native 02 vs source header COR1012-01'},{'offering':'GIS1005-02','reason':'source course number GIS1005-02 vs parenthetical 1분반; no section correction inferred'}],'productionEdited':False,'completionClaim':False}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print('58/1386;5new129plans source preserving')
