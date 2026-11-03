import pathlib,re,json,hashlib
P=pathlib.Path(__file__).parent;txt=(P/'eulji-2026-2.txt').read_text();assert '2026학년도' in txt and '2026.12.21.' in txt
pattern=re.compile(r'^\s*(?:(?P<area>[HUMAN]영역)\s+)?(?P<name>.+?)\s+(?P<section>\d{3})\s+(?:GRADE|P/NP)\s+(?P<credits>[23])\s+(?P<day>[월화수목금토])\s+(?P<unit>[주야])(?P<first>\d+)~(?:주)?(?P<last>\d+)\s+(?P<room>\S+)(?:\s+(?P<remark>.+))?\s*$')
campus='seongnam';area='';records={};held=[];pending=None
for line in txt.splitlines():
 if '의정부캠퍼스' in line:campus='uijeongbu';area=''
 match=pattern.match(line)
 if match:
  d=match.groupdict();name=re.sub(r'\s+','',d['name']);area=d['area'] or area
  if d['unit']=='야':held.append({'campus':campus,'raw':line,'reason':'night clock not published'});pending=None;continue
  a,b=int(d['first']),int(d['last']);assert 1<=a<=b<=9
  section=d['section'];identity=f'{campus}:{name}:{section}';department='교양';credit=int(d['credits']);remark=d['remark'] or ''
  obj={'sourceId':'eulji/'+campus+'/2026/2/'+hashlib.sha256(identity.encode()).hexdigest()[:24],'universityId':'eulji','campus':campus,'campusName':{'seongnam':'성남캠퍼스','uijeongbu':'의정부캠퍼스'}[campus],'academicYear':2026,'semester':'2','courseCode':'','courseName':name,'section':section,'professor':'','credits':credit,'schedules':[{'weekday':'월화수목금토일'.index(d['day'])+1,'startMinute':480+a*60,'endMinute':480+b*60+50,'classroom':d['room']}],'departments':[department],'departmentCredits':{department:credit},'departmentClassifications':{department:'교양 '+area},'departmentRemarks':{department:remark},'nativeRow':line.strip(), 'sourceSchedule':d['day']+' '+d['unit']+d['first']+'~'+d['last'], 'sourceClassroom':d['room'], 'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}}
  records[campus,identity]=obj;pending=obj
 elif pending and re.match(r'^\s{25,}\S',line) and '구분' not in line:
  # Native wrapped remarks occur to the right of the classroom column.
  continuation=line.strip()
  if continuation in ['제한','(내국인  학생  수강  불가)']:
   pending['departmentRemarks']['교양']+=' '+continuation
for campus in ['seongnam','uijeongbu']:
 courses=[v for (c,k),v in records.items() if c==campus]
 out={'schemaVersion':1,'universityId':'eulji','campus':campus,'campusName':{'seongnam':'성남캠퍼스','uijeongbu':'의정부캠퍼스'}[campus],'academicYear':2026,'semester':'2','sourceUrl':'https://www.anyang.ac.kr/main/communication/notice.do?mode=download&articleNo=40936&attachNo=16257','publishedDate':'2026-08-19','sourceSha256':hashlib.sha256((P/'eulji-2026-2.pdf').read_bytes()).hexdigest(),'sourceRowCount':len(courses),'courses':courses,'heldRows':[h for h in held if h['campus']==campus],'periodEvidence':{'start':'2026-09-01','end':'2026-12-21','sourceUrl':'https://www.anyang.ac.kr/main/communication/notice.do?mode=download&articleNo=40936&attachNo=16257','scope':'수업기간 explicit regular15weeks+보강'}}
 (P/f'eulji-{campus}-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(campus,len(courses),len(out['heldRows']))
