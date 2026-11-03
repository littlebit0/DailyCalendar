"""Six further individual current plans; no section/date/campus inference."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).parent
OUT=ROOT/'sogang-additions-v2-20261008'
BASE=ROOT/'sogang-additions-20261008/sogang-unknown-2026-2.forty-three-reviewed-20261008.json'
base=json.loads(BASE.read_text());result=copy.deepcopy(base);proofs=[]
for key,heldweeks,expected,notice in [
 ('COR1012-08',{4,7,8,15,16},21,'4주 도서관 연계특강 예정은 실제 일자·장소 미확인 보류. 7·15주 비대면 상담의 실시간 여부·개인 배정 시각 미확인 보류. 8주 과제 제출과 16주 퀴즈 실제 시험 시각 미확인 보류.'),
 ('COR1013-10',{6,8,15,16},23,'6주 도서관 연계특강 예정 실제 일자·장소 미확인 보류. 15주 비대면 개인 상담과 전체 강평의 일별 배정·시각 미확인 보류. 8주 지필시험 실제 날짜·시각 미확인과 16주 보고서 제출 보류.'),
 ('GIS1005-01',{8,16},27,'10/5 대체공휴일 휴강 제외, 보강 추후 논의이므로 임의 보강을 생성하지 않음. 8·16주 중간·학기말시험 실제 일자·시각 미확인 보류. 한국어 3급 이상 글로벌융합학부 학생 대상이며 한국어 수준에 따라 조정 예정. 노트북·태블릿 필수이고 휴대전화만으로 참여 불가·결석 처리, 수업 중 한국어만 사용, 5회 이상 결석 시 이수 불가.'),
 ('GIS2004-01',{8,16},27,'9/24 공휴일 제외. 8·16주 평가의 실제 날짜·시각 미확인 보류. 생성형 AI 활용 표시·저작권·인용·과제 기한 준수. 노트북 및 G-mail·Microsoft 계정은 실습 준비 조건이며 서비스·교육환경에 따라 도구 변경 가능, 무료 또는 학교 이용 가능한 서비스 우선.'),
 ('GIS2004-02',{8,16},27,'9/24 공휴일 제외. 8·16주 평가의 실제 날짜·시각 미확인 보류. 생성형 AI 활용 표시·저작권·인용·과제 기한 준수. 노트북 및 G-mail·Microsoft 계정은 실습 준비 조건이며 서비스·교육환경에 따라 도구 변경 가능, 무료 또는 학교 이용 가능한 서비스 우선.'),
 ('MGT3006-01',{8,16},25,'9/10 개강미사 휴강, 9/22·10/29 녹화 보강은 대면·고정 시간 수업 없음, 9/24 추석 휴강 제외. 계획서와 공시가 일치하는 10/20 중간시험 12:00~13:15 MA202만 별도 반영, 12/15 기말 날짜는 공개되나 실제 시험 시각 미확인 보류. 조별 프로젝트일은 교실 내 Q&A·그룹 작업으로 안내. 발표일 배정은 무작위 추첨이며 11/30 슬라이드 제출 마감은 출석 아님.')]:
 p=OUT/f'{key}.source-education.json';s=json.loads(p.read_text());row=s['currentPublicRow'];t=s['weeklyOperatingText'];compact=re.sub(r'\s+','',t)
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and all(row.get(k,'')==v for k,v in c['sourceEducationalMetadata'].items())
 assert s['currentBytesEqualPrior'] and c['courseCode'] in s['sourceHeader']
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);assert end-start==75
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1]
 weekdays={1,3} if key.startswith(('COR','GIS1005')) else {2,4}
 blocks=re.split(r'Week\s+(\d+)' if key.startswith('MGT') else r'(\d+)\s*주차',t)
 meetings=[];sourceweeks=[];holds=[]
 for i in range(1,len(blocks),2):
  week=int(blocks[i]);body=blocks[i+1];clean=re.sub(r'\s+','',body)
  if key.startswith('MGT'):
   header=body.split('Topics',1)[1].split('Class Work',1)[0] if 'Topics' in body else ''
   printed=re.findall(r'(\d{1,2})/(\d{1,2})\s*\((?:Tues|Thurs)\)',header)
  else:
   printed=re.findall(r'(\d{1,2})/(\d{1,2})',clean)[:2]
  assert len(printed)==2,(key,week,printed)
  dates=[dt.date(2026,int(m),int(d)) for m,d in printed]
  assert all(d.isoweekday() in weekdays for d in dates),(key,week,dates)
  if week in heldweeks:
   holds.append({'week':week,'dates':[d.isoformat() for d in dates],'sourceOperatingBody':body});continue
  for d in dates:
   date=d.isoformat()
   if date in {'2026-10-05','2026-09-24'} or (key.startswith('MGT') and date in {'2026-09-10','2026-09-22','2026-10-29'}):
    holds.append({'date':date,'reason':'source holiday/no class/recorded makeup'});continue
   meetings.append({'date':date,'weekday':d.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
  sourceweeks.append({'week':week,'printedDates':[d.isoformat() for d in dates],'sourceOperatingBody':body})
 if key.startswith('MGT'):
  assert row['exam']=='10.20(화)12:00~13:15[MA202]' and '10/20 (Tues) Midterm Exam' in t
  meetings.append({'date':'2026-10-20','weekday':2,'startMinute':start,'endMinute':end,'classroom':room})
 assert len(meetings)==expected,(key,len(meetings),expected)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:
  c['departmentRemarks'][dep]+='\n현재 해당 분반의 공개 계획서와 공시 시간표에서 확인되는 날짜별 정규 계획만 반영합니다. '+notice+' 확인 안 된 방식·캠퍼스·실제 출석을 추정하지 않습니다. 이후 운영 변경 공지를 확인하세요.'
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'sourceWeeks':sourceweeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==6 and set(changed)=={p['offering'] for p in proofs}
assert sum(bool(c['schedules']) for c in result['courses'])==49
assert sum(len(c['schedules']) for c in result['courses'])==1159
candidate=OUT/'sogang-unknown-2026-2.forty-nine-reviewed-20261008.json';candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':43,'previousPlans':1009,'addedScheduled':6,'addedPlans':150,'scheduled':49,'plans':1159,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'closureLimit':'Protected final cancellation detail remains unread; current public offerings present, whole reflection unproven.','deferredIdentityConflicts':[{'offering':'COR1012-02','reason':'native 02 vs source header COR1012-01'},{'offering':'GIS1005-02','reason':'source course number GIS1005-02 vs parenthetical 1분반; no section correction inferred'}],'productionEdited':False,'completionClaim':False}
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print('49/1159;6new/150plans source preserving')
