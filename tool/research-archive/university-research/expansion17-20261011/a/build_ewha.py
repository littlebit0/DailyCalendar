"""Transform official anonymous public undergraduate UI datasets, preserving native fields."""
import pathlib,json,xml.etree.ElementTree as E,re,hashlib
P=pathlib.Path(__file__).parent
runtime=json.loads(json.load(open(P/'ewha-runtime-fields.json'))['result']['value']);slots={};previous=0
for row in E.fromstring(runtime['hours']).findall('./Rows/Row'):
 cols={c.attrib['id']:c.text or '' for c in row};times=re.findall(r'(\d{1,2}):(\d{2})',cols['CD_KNM']);assert len(times)==2
 a,b=[int(h)*60+int(m) for h,m in times]
 # Native labels use a monotonic 12-hour clock, without AM/PM letters.
 while a<previous:a+=720
 while b<=a:b+=720
 slots[int(cols['COM_CD'])]=(a,b);previous=a
raw=[];sha=hashlib.sha256()
for f in sorted(P.glob('ewha-native-*.json')):
 sha.update(f.read_bytes());raw.extend(json.load(open(f))['rows'])
assert len(raw)==len({(r['SUBJECT_CD'],r['CLASS_NUM'])for r in raw})
courses=[];held=[]
for r in raw:
 days=(r.get('DAY_CD_E') or '').splitlines();periods=(r.get('HOUR1_E')or'').splitlines();rooms=(r.get('ROOM_NM_E')or'').splitlines();meetings=[];status='scheduled'
 if not days and not periods:status='unscheduled'
 elif len(days)!=len(periods):status='unrecognized';held.append({'code':r['SUBJECT_CD'],'section':r['CLASS_NUM'],'reason':'day/time line mismatch'})
 else:
  for i,(day,period) in enumerate(zip(days,periods)):
   m=re.fullmatch(r'(\d+)~(\d+)',period)
   if day not in '월화수목금토일' or not m or int(m[1])not in slots or int(m[2])not in slots:
    status='unrecognized';held.append({'code':r['SUBJECT_CD'],'section':r['CLASS_NUM'],'reason':'unknown native period','day':day,'period':period});break
   a,b=int(m[1]),int(m[2]);assert a<=b
   meetings.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':slots[a][0],'endMinute':slots[b][1],'classroom':rooms[i] if i<len(rooms)else ''})
 if status=='unrecognized':meetings=[]
 dept=r.get('CLS_MAJ_CD_NM') or '';credit=float(r['CREDIT']) if r['CREDIT'] else None;category=r.get('ISU_CD_NM')or'';remark=r.get('CLASS_REF')or''
 if r.get('CURRI_AREA_NM'):remark+='; 교양영역: '+r['CURRI_AREA_NM']
 if r.get('LECTURE_TYPE'):remark+='; '+r['LECTURE_TYPE']
 if r.get('GRADE'):remark+='; '+r['GRADE']
 courses.append({'sourceId':f"ewha/unknown/2026/2/{r['SUBJECT_CD']}/{r['CLASS_NUM']}",'universityId':'ewha','campus':'unknown','campusName':'캠퍼스 미표기','academicYear':2026,'semester':'2','courseCode':r['SUBJECT_CD'],'courseName':r['SUBJECT_NM_KOR'],'section':r['CLASS_NUM'],'professor':r.get('PROF_HNAME')or'','credits':credit,'classification':category,'sourceSchedule':r.get('LECTURE_TIME')or'','sourceClassroom':r.get('ROOM_NM_E')or'','scheduleStatus':status,'schedules':meetings,'departments':[dept] if dept else [],'departmentCredits':{dept:credit}if dept and credit is not None else {},'departmentClassifications':{dept:category}if dept else {},'departmentRemarks':{dept:remark.strip('; ')}if dept else {},'remarks':remark.strip('; '),'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}})
out={'schemaVersion':1,'universityId':'ewha','campus':'unknown','campusName':'캠퍼스 미표기','academicYear':2026,'semester':'2','sourceUrl':'https://eureka.ewha.ac.kr/eureka/my/public.do?pgId=P531005519','collectedDate':'2026-10-12','publishedDate':'','publishedDateUnavailable':True,'sourceSha256':sha.hexdigest(),'sourceRowCount':len(raw),'courses':courses,'heldRows':held,'periodEvidence':{'start':'2026-09-01','end':'2026-12-21','sourceUrl':'https://www.ewha.ac.kr/ewha/bachelor/calendar2026.do?mode=user_list&year=2026','basis':'9/1개강12/21종강'},'nativePeriodClocks':slots,'coverage':'All27nativecollegefilters; 16nonemptycollegecodes. Native unscheduled589 rows retained explicitly.'}
(P/'ewha-unknown-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(len(courses),sum(len(c['schedules'])for c in courses),'held',len(held),'unscheduled',sum(c['scheduleStatus']=='unscheduled'for c in courses))
