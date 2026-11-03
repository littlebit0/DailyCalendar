"""Build educational-whitelist public SWU plans; no production writes."""
import collections,datetime,hashlib,json,re
from pathlib import Path
P=Path(__file__).parent; D=P/'swu-current-20261008'
def read(p):return json.loads(p.read_text())
def write(name,x):
 p=D/name;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return {'file':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
init=read(D/'swu-onload.json')['root'];idx=read(D/'swu-acquisition-index.json')
assert len(idx)==172 and len({(x['div'],x['department']) for x in idx})==172
names={r['SA_CD']:r['SA_NM']for k in ['listNetSa','listNetConnSa','listHybirdMajor']for r in init[k]['row']}
byref=collections.defaultdict(list)
for q in idx:
 root=read(D/q['file'])['root'];assert not root.get('EXRIAERRMSG');rows=root['openSubList']['row'];assert len(rows)==q['rows']
 for r in rows:byref[r['REF_KEY']].append({'query':{k:q[k] for k in ['div','label','department']},'education':r})
assert len({(v[0]['education']['SB_CD'],v[0]['education']['DIVCLS_CD'])for v in byref.values()})==len(byref)
closed=read(P/'swu-final-cancellations.json');keys={(v[0]['education']['SB_CD'],int(v[0]['education']['DIVCLS_CD']))for v in byref.values()};assert not [x for x in closed if(x['subjectCode'],int(x['section']))in keys]
clock={i:(540+90*(i-1),615+90*(i-1))for i in range(1,7)};clock.update({i:(1080+60*(i-7),1130+60*(i-7))for i in range(7,12)})
weekdays='월화수목금토일';tenweeks=set(read(P/'swu-manifest.json')['concentratedUnresolved10Weeks'])
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
makeup={'2026-12-08':1,'2026-12-09':5,'2026-12-10':4,'2026-12-11':5}
regular=[datetime.date(2026,9,1)+datetime.timedelta(days=i)for i in range(98)]
assert regular[-1]==datetime.date(2026,12,7)
no_dates=[];courses=[];parse_gaps=[];timed_count=0
for ref,rows in sorted(byref.items()):
 r=rows[0]['education'];code=r['SB_CD'];section=r['DIVCLS_CD'];key=code+'-'+section; source=r['CLASS']; parts=source.split(' / ',1); times=parts[0];rooms=parts[1].splitlines()if len(parts)>1 else [];blocks=[]
 groups=list(re.finditer(r'([월화수목금토일])([0-9~+,]+)',times));remainder=re.sub(r'([월화수목금토일])([0-9~+,]+)','',times).strip('/ ')
 for j,g in enumerate(groups):
  day=weekdays.index(g[1])+1
  for period in g[2].split(','):
   bounds=period.split('~');a=int(bounds[0]);b=int(bounds[-1]);
   if a not in clock or b not in clock or a>b:continue
   room=rooms[j]if len(rooms)==len(groups)else rooms[0]if len(set(rooms))==1 and rooms else ''
   blocks.append({'weekday':day,'startMinute':clock[a][0],'endMinute':clock[b][1],'classroom':room})
 if remainder and times not in {'-0',''}:blocks=[];parse_gaps.append({'key':key,'source':source,'reason':'not standard weekly notation'})
 native_blocks=[dict(b) for b in blocks]
 notes=[r.get('PERMIT_LIMIT_NM',''), '학교 공개 시간표·지정보강 계획입니다. 실제 출석 및 개별 휴강·보강 확정이 아니며 기말고사와 자율보강은 강좌별 확인이 필요합니다.']
 for field,label in [('SB_LVL','이수학년'),('PRE_CURI_NM','선수과목'),('COCO_NM','교양영역'),('COCO_4_NM','교양영역'),('DCL_RCD_NM','학문영역'),('TRACK_CURI','트랙'),('CMP_DIV_SUB_NM','부전공'),('CMP_DIV_DBL_NM','복수전공')]:
  if r.get(field):notes.append(label+': '+r[field])
 schedules=[];period={'startDate':'2026-09-01','endDate':'2026-12-21'};meaning='published regular teaching and designated makeup plan';status='scheduled'
 if key in tenweeks:
  blocks=[];notes.append('10주 집중이수 강좌입니다. 정확한 수업일은 강의계획서 및 오리엔테이션에서 확인해야 하므로 학기 전체 반복 일정을 만들지 않았습니다.');meaning='10-week dates not published';status='unrecognized'
 elif code=='1111111' and int(section)>=6:
  blocks=[];notes.append('경건회 06~07분반은 녹화동영상입니다. 금7/금0은 실제 고정 강의시간으로 사용하지 않았습니다. 대면 경건회 4회 이상 이수 희망자 또는 편입생 대상이며 매회 소감문 제출 필요.');meaning='untimed prerecorded video';status='unscheduled'
 elif code=='1111112':
  blocks=[];notes.append('별도 경건회 코드의 일1 표시는 공식 운영안내와 대조되지 않아 실제 일정으로 사용하지 않았습니다.');meaning='unmatched chapel alias';status='unrecognized'
 elif code=='UA03011':
  n=int(section)
  if n<=43:
   blocks=[];notes.append('합숙/캠프형 바롬인성교육은 월~금8~9가 종합정보시스템 예약표시이며 실제 수업·생활교육 활동표와 다릅니다. 강좌별 실제 활동 시간표 확정 전 반복 강의를 만들지 않았습니다.');meaning='Bahrom native reservation withheld pending activity plan';status='unrecognized'
   group=next(x for x in read(P/'swu-manifest.json')['concentratedKnownPeriod']if n in x['sections']);period={'startDate':group['start'],'endDate':group['end']}
   notes.append('교육기간: '+group['start']+' ~ '+group['end']+ (' (9/21~9/25 교육 미운영)' if n<=13 else ''))
  else:
   dates=([ '09-07','09-14','09-21','09-28','10-12','10-26','11-02']if n<=49 else ['09-01','09-08','09-15','09-22','10-06','10-13']if n<=53 else ['09-04','09-11','09-18','10-02','10-16','10-30','11-06'])
   notes.append('공식 수강편람 인쇄82쪽의 비합숙 분반별 명시 수업일을 적용했습니다. '+('외국인학생 전 학과1~4학년 대상.'if n<=53 else '한국학생 사전 신청자 대상, 대학 일괄 수강신청.'))
   if 50<=n<=53:notes.append('공식 PDF에 "*11월에는 없는지"라는 미확정 문구가 있습니다. 공개된 6개 수업일만 반영했으며 11월 일정은 미확인입니다.')
   for date in dates:
    d=datetime.date.fromisoformat('2026-'+date)
    for b in blocks:schedules.append({**b,'date':str(d),'weekday':d.isoweekday()})
   meaning='explicit Bahrom non-residential dates, not attendance confirmation'
 elif code=='1111111':
  for b in blocks:b['endMinute']=b['startMinute']+50
  notes.append('경건회 대면01~05분반은 공식50분 수업이며 9/16부터 개강합니다. 전체 경건회 회차별 운영일은 추가 확인 필요.');blocks=[];status='unrecognized';meaning='chapel dates need session-specific calendar'
 if not schedules and blocks:
  for d in regular:
   if str(d) in holidays:continue
   for b in blocks:
    if b['weekday']==d.isoweekday():schedules.append({**b,'date':str(d)})
  for date,native_day in makeup.items():
   for b in blocks:
    if b['weekday']==native_day:schedules.append({**b,'date':date,'weekday':datetime.date.fromisoformat(date).isoweekday()})
 if not schedules:
  
  if status=='scheduled':
   status='unrecognized' if remainder and times not in {'-0',''} else 'unscheduled'
   meaning='source vacation notation lacks dated teaching plan' if status=='unrecognized' else 'source blank or zero-period notation has no published fixed teaching time'
  no_dates.append({'key':key,'reason':meaning,'nativeSchedule':source})
 unique={(s['date'],s['startMinute'],s['endMinute'],s['classroom']):s for s in schedules};schedules=sorted(unique.values(),key=lambda s:(s['date'],s['startMinute'],s['classroom']));timed_count+=len(schedules)
 depts=sorted({names[x['query']['department']]for x in rows if x['query']['department']in names});dc={};dr={};credits={}
 for x in rows:
  dept=names.get(x['query']['department']);rr=x['education']
  if dept:dc[dept]=rr['CMP_DIV_RCD_NM'];dr[dept]='\n'.join(filter(None,[rr.get('PERMIT_LIMIT_NM',''),*notes[1:]]));credits[dept]=float(rr['PNT'])
 course={'sourceId':'swu-2026-2-'+ref.split()[-1],'campus':'main','academicYear':2026,'semester':'2','courseCode':code,'courseName':r['SB_CD_NM'],'section':section,'professor':r['PROF_NM'],'credits':float(r['PNT']),'classification':r['CMP_DIV_RCD_NM'],'departments':depts,'departmentCredits':credits,'departmentClassifications':dc,'departmentRemarks':dr,'remarks':'\n'.join(filter(None,notes)),'sourceSchedule':source,'sourceClassroom':parts[1]if len(parts)>1 else'','scheduleStatus':status,'period':period,'schedules':schedules,'sourceSnapshotSchedules':native_blocks,'publicEducationBySelection':rows,'datesMeaning':meaning,'campusEvidence':'academyinfo:0000126 본교 institution scope; native catalog has no separate campus selector. Classroom remains exactly source.'}
 courses.append(course)
entry=write('swu-main-2026-2.published-safe-next-20261008.json',{'schemaVersion':2,'universityId':'swu','campus':'main','campusName':'본교','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://swis.swu.ac.kr/json/ccs/extCcsSOpenSubSearch.xrf','courses':courses})
write('audit.json',{'completionClaim':False,'queryCount':len(idx),'queryRows':sum(x['rows']for x in idx),'uniqueClasses':len(courses),'scheduledClasses':sum(bool(x['schedules'])for x in courses),'datedMeetings':timed_count,'untimedOrUnresolved':no_dates,'nativeNotationGaps':parse_gaps,'finalClosureCount':len(closed),'finalClosuresStillPresent':0,'datasets':[entry],'academicPeriod':['2026-09-01','2026-12-21'],'regularTeachingDatesThrough':'2026-12-07','makeupNativeWeekday':makeup,'excludedHolidays':sorted(holidays),'heldNotConfirmed':True,'unverified':['final and autonomous makeup individual plans','Bahrom camp and residential actual activities differ from native reservation','10week exact dates','chapel session-specific dates and extra alias','native category ** and 평교/복필 broader mappings'],'noLoginOrVisibleUI':True,'publicUIRequestSource':'predecessor swu-catalog.js and swu-model.xml; 172 actual onLoad selectable pairs','educationalWhitelistOnly':True})
print(json.dumps({'classes':len(courses),'scheduled':sum(bool(x['schedules'])for x in courses),'meetings':timed_count,'queryRows':sum(x['rows']for x in idx),'gaps':len(parse_gaps),'candidate':entry},ensure_ascii=False))
