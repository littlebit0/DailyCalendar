import json,re,hashlib,copy,datetime,collections
from pathlib import Path
P=Path(__file__).parent; I=P.parent
base=I/'sch-unknown-2026-2.accounting-thirteen-next.json'
def save(n,d): (P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
b=json.loads(base.read_text());out=copy.deepcopy(b)
clock={'observedAt':'2026-10-08','noticeUrl':'https://home.sch.ac.kr/cultureindustry/04/0101.jsp?article_no=20260809034223473092&mode=view','actualAttachmentUrl':'https://home.sch.ac.kr/_custom/sch/_common/board/download.jsp?attach_no=20260911101543239012','attachmentSHA256':hashlib.sha256(Path('/private/tmp/sch-cultureindustry-2026-2.xlsx').read_bytes()).hexdigest(),'sheet':'실제','publishedTitle':'2026학년도 2학기 글로벌문화산업학과 시간표','regularSlots':[{'nativePeriod':str(n),'startMinute':540+(n-1)*60,'endMinute':590+(n-1)*60,'cell':f'B{6+(n-1)*2}'} for n in range(1,13)],'blockSlots':[{'nativeBlock':str(n),'startMinute':s,'endMinute':s+75,'cell':f'C{6+(n-1)*3}'} for n,s in enumerate([540,630,720,810,900,990,1080,1170],1)],'scope':'Current undergraduate department chart directly labels Regular and Block clocks. Crossproof against current whole catalog notation and current accounting daytime grid; no claimed 13+ or institution-wide actual attendance. Latest attachment differs from search-cached August attachment; real current page links used.','currentFixedTimetableRule':{'url':'https://rule.sch.ac.kr/lmxsrv/law/lawFullContent.srv?SEQ=311&SEQ_HISTORY=3302','effectiveDate':'2026-09-01','article':'제19조(수업시간표)','text':'매학기의 수업시간표는 고정시간표로 운영함을 원칙으로 한다.'},'completionClaim':False}
existing_clock=P/'current-clock-education.json'
if existing_clock.exists():
 for key,value in json.loads(existing_clock.read_text()).items():
  if key not in clock: clock[key]=value
save('current-clock-education.json',clock)
# Whole catalog 2026-2 native period notation; AB75 correspondence from current accounting chart and new current Block chart.
ab={'1A-2A':(540,615),'2B-3B':(630,705),'4A-5A':(720,795),'5B-6B':(810,885),'7A-8A':(900,975),'8B-9B':(990,1065),'10A-11A':(1080,1155),'11B-12B':(1170,1245)}
# Current independent department sheet conflicts remain explicit. Do not replace catalog values.
conflict={'12645':'new department sheet U1210 vs current catalog U1209','12692':'new department sheet U1210 vs current catalog U212','12705':'new department sheet U1210 vs current catalog U1209','12904':'new department sheet U1214 vs current catalog U1208','10517':'new department sheet U1214 vs current catalog U1209','10507':'new department sheet U1210 vs current catalog U1209','10510':'new department sheet U1210 vs current catalog U1209','10509':'new department sheet two named professors vs catalog one; whole instructor correspondence pending'}
def blocks(c):
 text=c['sourceSchedule'] or ''; rooms=c['sourceClassroom'] or ''
 if not text:return None,'no-published-time'
 if not rooms:return None,'no-published-room'
 if c['sourceEducationalMetadata'].get('operatingReviewScope') in ['official-OCU-query','official-internal-virtual-query']:return None,'actual-remote-query'
 if c['sourceEducationalMetadata'].get('educationalOperatingNotes'):return None,'actual-operating-exception'
 if c['courseCode'] in conflict:return None,'current-department-source-conflict'
 # Each slash segment must carry explicit day; parallel rooms only when exact segment count.
 segments=text.split('/');rs=rooms.split('/')
 if len(rs)>1 and len(rs)!=len(segments):return None,'ambiguous-room-day-correspondence'
 ans=[]
 for i,seg in enumerate(segments):
  m=re.fullmatch(r'([월화수목금토일])(.+)',seg)
  if not m:return None,'unparsed-native-time'
  day='월화수목금토일'.index(m[1])+1;room=rs[i] if len(rs)>1 else rooms
  for token in m[2].split(','):
   if token in ab:s,e=ab[token]
   elif re.fullmatch(r'[0-9]+',token) and 1<=int(token)<=12:s=540+(int(token)-1)*60;e=s+50
   else:return None,'unsupported-period-or-range'
   ans.append({'weekday':day,'startMinute':s,'endMinute':e,'classroom':room})
 return ans,None
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-09-27','2026-10-03','2026-10-05','2026-10-09'}
start=datetime.date(2026,8,31);end=datetime.date(2026,12,6)
held=collections.Counter();added=[];proof=[]
for old,c in zip(b['courses'],out['courses']):
 if old['schedules']:continue
 bs,reason=blocks(c)
 if reason:held[reason]+=1;proof.append({'sourceId':c['sourceId'],'reason':reason,'detail':conflict.get(c['courseCode'])});continue
 sch=[];date=start
 while date<=end:
  ds=date.isoformat()
  if ds not in holidays and not ('2026-10-19'<=ds<='2026-10-23'):
   sch.extend({**bl,'date':ds} for bl in bs if bl['weekday']==date.isoweekday())
  date+=datetime.timedelta(days=1)
 if not sch:held['no-dates-in-proven-bounds']+=1;continue
 c['schedules']=sch;c['scheduleStatus']='scheduled'
 c['nativeReservationBlocks']=bs
 c['reservationProof']={'clockReceipt':'current-clock-education.json','termReceipt':'../sch-2026-calendar-dom.json','dateScope':'2026-08-31–2026-12-06 regular reservation only; intermediate exams Oct19–23 held, finals Dec7–11 and makeup Dec14–18 outside; legal holidays held','actualAttendanceVerified':False,'individualOperationVerified':False,'hyflexAssignmentVerified':False,'deliveryModeOverride':False}
 note='현재 공개 시간표 예약 계획. 학교 현재 학부 Regular1–12교시/75분 Block시각을 적용; 실제 출석·개별 시험·보강·최신 폐강/수강제한 미확인. 중간시험 및 공휴일 예약 보류. 실제 배정된4/5학년 하이플렉스만 선택 대상이며 개별 배정 미확인; 사용자 선택 방식 유지. 원문 교수·강의실·수강번호·분반 그대로 보존; 캠퍼스 미확인.'
 for dep in c['departments']:c['departmentRemarks'][dep]=(c['departmentRemarks'].get(dep,'')+'\n'+note).strip()
 added.append(c['sourceId'])
assert len(out['courses'])==2598
assert all(a==z for a,z in zip(b['courses'],out['courses']) if a['schedules'])
for a,z in zip(b['courses'],out['courses']):
 for k in a:
  if k not in ['schedules','scheduleStatus','departmentRemarks']:assert a[k]==z[k],(a['sourceId'],k)
save('sch-unknown-2026-2.ordinary-reservation-v2.json',out)
save('held-source-reasons.json',proof)
audit={'inputObjects':2598,'originalScheduled':13,'originalMeetings':263,'preservedOriginalScheduledDeep':True,'addedScheduled':len(added),'scheduled':sum(bool(c['schedules']) for c in out['courses']),'datedMeetings':sum(len(c['schedules']) for c in out['courses']),'held':dict(held),'addedSourceIds':added,'wholeNativeMetadataPreserved':True,'wholeLatestClosureVerified':False,'wholeCurrentDepartmentCorrectionVerified':False,'completionClaim':False,'productionEdited':False,'sourceBaseSHA256':hashlib.sha256(base.read_bytes()).hexdigest()}
save('candidate-audit.json',audit);print(json.dumps({k:v for k,v in audit.items() if k!='addedSourceIds'},ensure_ascii=False))
