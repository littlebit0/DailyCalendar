"""Read native final PDF grid cell extents; keep explicitly published half-term ranges."""
import pathlib,json,re,hashlib,pdfplumber
P=pathlib.Path(__file__).parent;pdf=pdfplumber.open(P/'iccu-nursing-final.pdf');records={};held=[]
for pageindex,page in enumerate(pdf.pages):
 table=page.find_tables()[0];rows=table.extract();bounds=[c[2] for c in table.rows[0].cells];startrow=[i for i,r in enumerate(rows)if i>1 and r[2]=='지하101호'];assert len(startrow)==5
 phase=('상반기','2026-09-01','2026-10-26')if pageindex==0 else ('하반기','2026-10-27','2026-12-22')
 header=page.extract_text().splitlines()[0];assert phase[0]in header
 for day,first in enumerate(startrow,1):
  last=startrow[day]if day<5 else len(rows);nursing=False;grade=''
  for ri in range(first,last):
   r=rows[ri]
   if r[1]and re.search(r'\d학년',r[1]):nursing=True;grade=r[1]
   if r[1]and '대학원' in r[1]:break
   dept='간호학과'if nursing else 'ELPIS교양대학'
   for ci in range(3,13):
    raw=r[ci]
    if not raw:continue
    # Explicit clinical rotation periods have different bounds/locations from
    # theory. Preserve unresolved rows instead of applying theory recurrence.
    if re.search(r'(성인간호학실습|간호관리학실습|지역사회간호학실습|정신간호학실습|통합시뮬레이션|종합실습)',raw):
     held.append({'page':pageindex+1,'row':ri,'column':ci,'raw':raw,'reason':'clinical rotation periods and placements require separate exact metadata'});continue
    box=table.rows[ri].cells[ci];assert box
    stop=next((k for k,x in enumerate(bounds)if abs(x-box[2])<.2),None);assert stop is not None and stop>=ci
    a=540+(ci-3)*60;b=540+(stop-3)*60+50 if stop<12 else 1260
    parts=[x.strip()for x in raw.replace('\n',' ').split(',')];name=parts[0];section=re.search(r'\((\d+)\)',name);section=section[1]if section else '';name=re.sub(r'\(\d+\)','',name).strip();classification='교필'if '[교필]'in name else '';name=name.replace('[교필]','').strip()
    if name.startswith('* 교외수업 *'):name=name.replace('* 교외수업 *','').strip()
    if name.startswith('* 원격수업 *'):name=name.replace('* 원격수업 *','').strip()
    room=re.findall(r'\d+호',raw);room=room[-1]if room else (r[2]if not nursing and r[2]and'호'in r[2]else '')
    teachers=[re.sub(r'\d+호','',x).strip() for x in parts[1:]if not re.search(r'실습지도|집담회',x)];teachers=[x for x in teachers if x];prof=', '.join(teachers);kind=phase[0];key=json.dumps([kind,name,section,prof,dept],ensure_ascii=False)
    if key not in records:records[key]={'sourceId':'iccu/songdo/2026/2/'+hashlib.sha256(key.encode()).hexdigest()[:24],'universityId':'iccu','campus':'songdo','campusName':'송도국제캠퍼스','academicYear':2026,'semester':'2','courseCode':'','courseName':name,'section':section,'professor':prof,'schedules':[],'departments':[dept],'departmentCredits':{},'departmentClassifications':{dept:classification},'departmentRemarks':{dept:kind+' 이론시간표; 학점·과목코드 원문 미표기'},'sourceSchedule':'','sourceClassroom':'','sourcePages':[pageindex+1],'period':{'startDate':phase[1],'endDate':phase[2]},'nativeCells':[]}
    obj=records[key];meeting={'weekday':day,'startMinute':a,'endMinute':b,'classroom':room}
    if meeting not in obj['schedules']:obj['schedules'].append(meeting)
    obj['sourceSchedule']+=(' / 'if obj['sourceSchedule']else '')+'월화수목금토일'[day-1]+f' {ci-2}~{stop-2}교시';obj['sourceClassroom']+=(' / 'if obj['sourceClassroom']else '')+room;obj['nativeCells'].append({'row':ri,'column':ci,'raw':raw,'cell':box})
# Adjacent published half-terms may be combined only when every actual
# meeting, professor, section, department and classification is identical.
groups={}
for c in records.values():
 key=json.dumps([c['courseName'],c['section'],c['professor'],c['departments'],c['schedules'],c['departmentClassifications']],ensure_ascii=False,sort_keys=True)
 prior=groups.get(key)
 if prior and prior['period']['endDate']=='2026-10-26' and c['period']['startDate']=='2026-10-27':
  prior['period']['endDate']='2026-12-22';prior['sourcePages']=[1,2];prior['nativeCells']+=c['nativeCells'];prior['departmentRemarks'][prior['departments'][0]]='상반기·하반기 동일한 원문 수업; 학점·과목코드 원문 미표기'
 else:groups[key]=c
records=groups
out={'schemaVersion':1,'universityId':'iccu','campus':'songdo','campusName':'송도국제캠퍼스','academicYear':2026,'semester':'2','sourceUrl':'https://nursing.iccu.ac.kr/board/free/photo/k_202609020152270.pdf','sourcePageUrl':'https://nursing.iccu.ac.kr/academic/timetable.php','publishedDate':'2026-09-01','sourceSha256':hashlib.sha256((P/'iccu-nursing-final.pdf').read_bytes()).hexdigest(),'sourceRowCount':len(records),'courses':list(records.values()),'heldRows':held,'periodEvidence':{'start':'2026-09-01','end':'2026-12-22','sourceUrl':'https://nursing.iccu.ac.kr/board/free/photo/k_202609020152270.pdf','basis':'native PDF 상반기9/1~10/26,하반기10/27~12/22; eachcourseexactphaseperiod'},'coverage':'Published nursing theory and ELPIS timetable; clinically rotated rows held. Separate native half-term course records, no recurrence outside phase.'}
(P/'iccu-songdo-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(len(records),sum(len(c['schedules'])for c in records.values()),len(held))
