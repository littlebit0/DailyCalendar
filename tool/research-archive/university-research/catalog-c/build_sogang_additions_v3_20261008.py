"""Four current public offerings, preserve source typos and online ambiguity."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).parent;OUT=ROOT/'sogang-additions-v3-20261008'
BASE=ROOT/'sogang-additions-v2-20261008/sogang-unknown-2026-2.forty-nine-reviewed-20261008.json'
base=json.loads(BASE.read_text());result=copy.deepcopy(base);proofs=[]
for key,expected,note in [
 ('COR1013-05',23,'계획서 5주 9/29는 화요일로 공시 수·금과 충돌하므로 보류하며 9/30으로 수정하지 않습니다. 9/18 축제 기간 운영 미확인, 9/25·10/9 공휴일과 학교 11/20 스터디데이 휴강을 보류/제외합니다. 중간시험은 10/21·23 주간 표기뿐이라 정확 시험 날짜·시각 미확인, 기말은 과제 대체이므로 시험 예약을 출석으로 만들지 않습니다. 1학년 권장, 글쓰기·토론·개인 성찰·제출 기한 조건과 후속 변경을 확인하세요.'),
 ('CSE2035-01',24,'계획서에 CSE2035 / AIE2051와 Class 1을 함께 명시합니다. 다른 공식 과목번호를 같은 과목으로 임의 합치지 않습니다. 컴퓨터/인공지능을 주전공으로 하는 학생만 신청 가능, 타전공·복수전공 불가이며 학번 끝자리 1·3·5 대상 조건을 보존합니다. 9/18 축제 운영 미확인 보류, 9/25·10/9 휴일 제외, 11/20 당일 사이버캠퍼스 온라인 강의·실습 보강은 실시간 여부 미확인으로 고정 출석을 생성하지 않습니다. 중간·기말 시험기간만 계획서에 게시되어 실제 날짜·시각 배정 보류.'),
 ('AIE2051-01',24,'계획서에 CSE2035 / AIE2051와 Class 1을 함께 명시합니다. 다른 공식 과목번호를 같은 과목으로 임의 합치지 않습니다. 컴퓨터/인공지능을 주전공으로 하는 학생만 신청 가능, 타전공·복수전공 불가이며 학번 끝자리 1·3·5 대상 조건을 보존합니다. 9/18 축제 운영 미확인 보류, 9/25·10/9 휴일 제외, 11/20 당일 사이버캠퍼스 온라인 강의·실습 보강은 실시간 여부 미확인으로 고정 출석을 생성하지 않습니다. 중간·기말 시험기간만 계획서에 게시되어 실제 날짜·시각 배정 보류.'),
 ('MGT3002-01',27,'계획서의 개별 게시 날짜별 교실 수업 26회와 공시·계획서가 일치하는 10/26 중간시험 1회를 반영합니다. 10/5 공휴일 온라인 학습과 10/12 Online 수업은 실시간 여부 미확인으로 고정 출석을 생성하지 않습니다. 10/21도 계획서 중간시험으로 기재되어 있으나 해당 분반 공시 시험은 10/26으로 배정되어 10/21은 보류합니다. 12/16·21 기말시험의 실제 일자·시각 미확인 보류. 계획서 교실 MA 표기보다 현재 공시 MA104 지정값을 보존합니다. 경영대학 3·4학년 대상(선수과목 없음)과 주어진 공시 수강대상·권장학년을 구분하며 변경 공지를 확인하세요.')]:
 s=json.loads((OUT/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];t=s['weeklyOperatingText']
 c=next(c for c in result['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and all(row.get(k,'')==v for k,v in c['sourceEducationalMetadata'].items())
 assert s['currentBytesEqualPrior'] and c['courseCode'] in s['sourceHeader']
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);assert end-start==75
 room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1];weekdays={1,3} if key.startswith('MGT') else {3,5}
 meetings=[];weeks=[];holds=[]
 if key.startswith('MGT'):
  entries=list(re.finditer(r'W(\d+)\s+(\d{1,2})/(\d{1,2})',t))
  assert len(entries)==32
  for i,m in enumerate(entries):
   week=int(m[1]);d=dt.date(2026,int(m[2]),int(m[3]));body=t[m.end():entries[i+1].start() if i+1<len(entries) else len(t)]
   assert d.isoweekday() in weekdays
   if week in (8,16) or 'Online' in body:
    holds.append({'date':d.isoformat(),'sourceOperatingBody':body,'reason':'exam actual allocation or online live/recorded unresolved'});continue
   meetings.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
   weeks.append({'week':week,'printedDates':[d.isoformat()],'sourceOperatingBody':body})
  assert row['exam']=='10.26(월)10:30~11:45[MA104]'
  meetings.append({'date':'2026-10-26','weekday':1,'startMinute':start,'endMinute':end,'classroom':room})
  holds=[h for h in holds if h['date']!='2026-10-26']
 else:
  blocks=re.split(r'(\d+)\s*주차',t)
  for i in range(1,len(blocks),2):
   week=int(blocks[i]);body=blocks[i+1];dates=re.findall(r'(\d{1,2})/(\d{1,2})',re.sub(r'\s+','',body))[:2]
   assert len(dates)==2
   for mm,dd in dates:
    d=dt.date(2026,int(mm),int(dd));date=d.isoformat()
    if week in (8,16) or date in {'2026-09-18','2026-09-25','2026-10-09','2026-11-20'}:
     holds.append({'date':date,'week':week,'reason':'exam unspecified, holiday/festival uncertainty, or online makeup unspecified'});continue
    if d.isoweekday() not in weekdays:
     assert key=='COR1013-05' and date=='2026-09-29'
     holds.append({'date':date,'week':week,'reason':'source Tuesday conflicts native Wed/Fri; no correction inferred'});continue
    meetings.append({'date':date,'weekday':d.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
   weeks.append({'week':week,'printedDates':[dt.date(2026,int(m),int(d)).isoformat() for m,d in dates],'sourceOperatingBody':body})
 assert len(meetings)==expected,(key,len(meetings),expected)
 meetings.sort(key=lambda m:m['date'])
 c.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(meetings),'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n현재 공개 분반 계획서와 공시 시간표에서 일치하는 정규 날짜 계획만 반영합니다. '+note
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'sourceWeeks':weeks,'holds':holds,'meetings':meetings,'addedPlans':len(meetings),'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert len(changed)==4
assert sum(bool(c['schedules']) for c in result['courses'])==53
assert sum(len(c['schedules']) for c in result['courses'])==1257
p=OUT/'sogang-unknown-2026-2.fifty-three-reviewed-20261008.json';p.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'candidateFile':p.name,'candidateSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':49,'previousPlans':1159,'addedScheduled':4,'addedPlans':98,'scheduled':53,'plans':1257,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'completionClaim':False,'productionEdited':False,'deferredReview':[{'offering':'MAT3310-01','reason':'minimum13 live Zoom classes/offline classroom required, remaining sessions may recorded; per-date allocation unknown. Midterm plan13:30~14:50 vs public13:30~14:45 conflict; held.'},{'offering':'MGT3001-01','reason':'100%online learning, fixed live vs recorded unpublished; no classroom schedule inferred.'},{'offering':'LCS2003-05','reason':'2026-2 date headers vs spring April/June date bodies conflict; not silently corrected.'}]}
(OUT/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('53/1257;4new98sourceplans')
