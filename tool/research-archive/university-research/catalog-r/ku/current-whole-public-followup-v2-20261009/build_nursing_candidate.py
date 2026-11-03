from pathlib import Path
import json,re,datetime,hashlib,copy
P=Path(__file__).parent
# root-ku is under university-research, not catalog-r.
source=P.parents[2]/'root-ku-normal-ui-20261009'/'seoul-nursing-current53-education.json'
x=json.loads(source.read_text());assert x['selectedCampus']=='서울' and x['selectedYear']==2026 and x['selectedSemester']=='2R' and x['displayedTotal']==x['capturedRows']==len(x['rows'])==53
(P/'source-nursing53-education.json').write_bytes(source.read_bytes());receipt=source.with_name('seoul-nursing-current53-receipt.json');(P/'source-nursing53-receipt.json').write_bytes(receipt.read_bytes());assert hashlib.sha256(source.read_bytes()).hexdigest()==json.loads(receipt.read_text())['sha256']
closed=set(json.loads((P/'closure-cumulative-scope-audit.json').read_text())['knownSeoulClosedUnion']);cal=json.loads((P/'current-2026-2-calendar-education.json').read_text());holidays=set(cal['holidays']);rows=[];proof=[]
def periods(v):
 out=[]
 for part in v.split(','):
  ns=re.split(r'[-~]',part);out.extend(range(int(ns[0]),int(ns[-1])+1))
 return out
def minute(h,m):return int(h)*60+int(m)
for raw in x['rows']:
 code=raw['COUR_CD'];section=raw['COUR_CLS'];identity=code+'-'+section;assert raw['YEAR']=='2026' and raw['TERM']=='2R' and raw['CAMPUS']=='서울'
 allocations={};native=[];holds=[]
 for line in raw['TIME_ROOM'].splitlines():
  m=re.fullmatch(r'([월화수목금토일])\(([^)]+)\)\s+(.+)',line.strip())
  if not m:holds.append('current time-room line unresolved');continue
  day='월화수목금토일'.index(m[1])+1
  for p in periods(m[2]):
   key=(day,p)
   if key in allocations and allocations[key]!=m[3]:holds.append('sameperiod currentroom conflict')
   allocations[key]=m[3];native.append({'weekday':day,'period':p,'room':m[3]})
 clock=[];covered=set();lastday=None;matches=list(re.finditer(r'(?:([월화수목금토일])\s*)?(\d+(?:\s*[~-]\s*\d+)?)교시\((\d{1,2}):(\d{2})[~-](\d{1,2}):(\d{2})\)',raw['APPLY_DEPT']))
 if not raw['TIME_ROOM']:holds.append('current clinical lectureclock/room allocation unpublished')
 if not matches:holds.append('direct current courseclock absent')
 for m in matches:
  explicitday=m[1];day='월화수목금토일'.index(explicitday)+1 if explicitday else lastday
  ps=periods(re.sub(r'\s','',m[2]));keys={(day,p) for p in ps};rooms={allocations.get(k) for k in keys}
  if day is None or None in rooms or len(rooms)!=1:holds.append('directclock nativeperiod/room unmatched');continue
  start=minute(m[3],m[4]);end=minute(m[5],m[6]);assert 0<=start<end<=1440
  clock.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':next(iter(rooms)),'sourcePeriods':ps,'sourceDirectClockText':m[0],'weekdayEllipsisInherited':explicitday is None});covered|=keys;lastday=day
 if covered!=set(allocations):holds.append('directclock not complete currentnative allocation')
 residue=re.sub(r'\[강의시간\]|[,\s]','',re.sub(r'(?:([월화수목금토일])\s*)?(\d+(?:\s*[~-]\s*\d+)?)교시\((\d{1,2}):(\d{2})[~-](\d{1,2}):(\d{2})\)','',raw['APPLY_DEPT']))
 if residue:holds.append('unparsed direct operating remark')
 if identity in closed:holds.append('current officially closednative')
 start=raw['FLEXIBLE_FR_DT'] or cal['semesterStart'];end=raw['FLEXIBLE_TO_DT'] or cal['semesterEnd'];assert re.fullmatch(r'2026-\d{2}-\d{2}',start) and re.fullmatch(r'2026-\d{2}-\d{2}',end) and start<=end
 last=min(end,cal['ordinaryReservationEndDerived']);schedules=[]
 if not holds:
  date=datetime.date.fromisoformat(start)
  while str(date)<=last:
   ds=str(date)
   if ds not in holidays and not(cal['midtermStart']<=ds<=cal['midtermEnd']):
    for s in clock:
     if date.isoweekday()==s['weekday']:schedules.append({k:v for k,v in s.items() if k not in ['sourcePeriods','sourceDirectClockText','weekdayEllipsisInherited']}|{'date':ds})
   date+=datetime.timedelta(days=1)
 title=raw['COUR_NM'].split('\n')[0].strip();note='현재2026-2 공개 수강조회 화면의 학수번호·분반·강사·강의실 및 과목별 공표 실제 시각을 보존한 주간 예약 계획입니다. 일반 서울 교시표보다 비고의 과목별 실제HH:mm를 우선 적용했습니다. 개별 출석·시험·보강의 확정 날짜가 아닙니다. 중간고사10/20–26·기말12/14–18 및 학교 공휴일 예약은 제외하며 미배정시험을 만들지 않습니다. 실제 수업방식 미지정으로 사용자 선택을 보존합니다. 현재 전체폐강 완전성은 미확인입니다.'
 if raw['FLEXIBLE_FR_DT'] or raw['FLEXIBLE_TO_DT']:note+=' 공개 개별 운영기간 '+start+'~'+end+'을 보존했으며 유연학기표시가 비어 있다고 개별기간을 지우지 않았습니다.'
 if holds:note+=' 일정 보류: '+' / '.join(holds)
 c={'sourceId':'korea/seoul/2026-2/'+identity,'campus':'seoul','academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':title,'professor':raw['PROF_NM'],'classification':raw['ISU_NM'],'credits':float(raw['CREDIT']),'departments':[raw['DEPARTMENT']],'departmentCredits':{raw['DEPARTMENT']:float(raw['CREDIT'])},'departmentClassifications':{raw['DEPARTMENT']:raw['ISU_NM']},'sourceSchedule':raw['TIME_ROOM'],'sourceClassroom':' / '.join(dict.fromkeys(v for v in allocations.values())),'remarks':note,'scheduleStatus':'scheduled' if schedules else 'unscheduled','schedules':schedules,'period':{'startDate':start,'endDate':end},'sourceEducationalMetadata':copy.deepcopy(raw),'sourceNativeAllocations':native,'sourceCurrentDirectClockSegments':clock,'reservationOnly':True,'actualAttendanceConfirmed':False,'sourceOwnUniversityTerm':{'startDate':cal['semesterStart'],'endDate':cal['semesterEnd']},'sourceOperatingHolds':holds}
 rows.append(c);proof.append({'identity':identity,'title':title,'currentSourceSemester':'2R','currentNativeClockCount':len(clock),'scheduled':bool(schedules),'meetings':len(schedules),'explicitCoursePeriod':bool(raw['FLEXIBLE_FR_DT'] or raw['FLEXIBLE_TO_DT']),'period':c['period'],'holds':holds,'nativeClosed':identity in closed})
assert len({c['sourceId'] for c in rows})==53
candidate={'schemaVersion':2,'universityId':'korea','campus':'seoul','campusName':'서울캠퍼스','academicYear':2026,'semester':'2','publishedDate':'2026-10-09','sourceUrl':'https://sugang.korea.ac.kr/','researchOnly':True,'completionClaim':False,'courses':rows};f=P/'korea-seoul-2026-2.nursing-native53-reviewed-v2-20261009.json';f.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n');a={'researchOnly':True,'completionClaim':False,'normalPublicUIWholeNursingCaptured':53,'wholeUniversityCatalogComplete':False,'scheduled':sum(bool(r['schedules']) for r in rows),'meetings':sum(len(r['schedules']) for r in rows),'sourceEducationSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'nativeClosedIntersection':[r['identity'] for r in proof if r['nativeClosed']],'perCourseProofs':proof,'SDKUsed':False,'actualFixture':'pending','productChanged':False};(P/'nursing-native53-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in a.items() if k!='perCourseProofs'})
