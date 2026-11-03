import pathlib,json,pdfplumber,re,hashlib,datetime,copy,collections
b=pathlib.Path(__file__).parent;o=b/'daegu-sookmyung-ssu-held-native-bulk-v1-20261010';pdfpath=b/'daegu-current-20261008/timetable-2026-2.pdf'
def load(n):return json.load(open(o/n))
def write(n,x):(o/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
base=load('baseline-daegu-main-2026-2.json');candidate=copy.deepcopy(base);courses={c['sourceId']:c for c in candidate['courses']};pending=load('possible-new-ordinary-scope-not-projected.json');receipts=[];positive=[];pagecache={};rx=re.compile(r'^([월화수목금토일])\((\d\d?:\d\d)-(\d\d?:\d\d)\)$');holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
with pdfplumber.open(pdfpath) as pdf:
 for p in pending:
  c=courses[p['sourceId']];rr=[];aliases=[];fail=[]
  for src in c['publicEducationRows']:
   num=src['sourcePage'];page=pdf.pages[num-1]
   if num not in pagecache:pagecache[num]=page.find_tables()
   table=pagecache[num][src['tableIndex']];matching=[(i,row) for i,row in enumerate(table.extract()) if row and len(row)>9 and row[3]==c['courseCode'] and row==src['sourceCells']]
   if len(matching)!=1:fail.append('exactSourceCellsRegistrationTableRowNotUnique');continue
   i,row=matching[0];tw=page.crop(table.rows[i].cells[8]).extract_words();rw=page.crop(table.rows[i].cells[9]).extract_words();tlines=collections.defaultdict(list);rlines=collections.defaultdict(list)
   for w in tw:tlines[round(w['top'],3)].append(w)
   for w in rw:rlines[round(w['top'],3)].append(w)
   slots=[];lines=[]
   if len(tlines)!=len(rlines):fail.append('unequalPrintedTimeRoomLineCount')
   for y,ws in sorted(tlines.items()):
    clock=''.join(w['text'] for w in sorted(ws,key=lambda w:w['x0']));match=rx.fullmatch(clock);ys=[a for a in rlines if abs(a-y)<=0.1]
    if not match or len(ys)!=1:fail.append('noUniqueExactSameYTimeRoomAlignment');continue
    rooms=' '.join(w['text'] for w in sorted(rlines[ys[0]],key=lambda w:w['x0']))
    if not re.fullmatch(r'[가-힣A-Za-z0-9]+관-[A-Za-z0-9]+',rooms):fail.append('printedRoomContainsMultipleOrNonLiteralAssignment');continue
    day,a,z=match.groups();minutes=lambda t:int(t.split(':')[0])*60+int(t.split(':')[1]);slot={'weekday':'월화수목금토일'.index(day)+1,'startMinute':minutes(a),'endMinute':minutes(z),'classroom':rooms}
    if slot['endMinute']<=slot['startMinute']:fail.append('invalidNativeHH');continue
    slots.append(slot);lines.append({'printedTime':clock,'printedRoom':rooms,'clockTop':y,'roomTop':ys[0],'samePrintedY':True,'clockWords':ws,'roomWords':rlines[ys[0]],'nativeSlot':slot})
   if len(slots)!=len(tlines):fail.append('notEveryPrintedTimeLineResolved')
   aliases.append(slots);rr.append({'pdfPage':num,'tableIndex':src['tableIndex'],'pdfTableRowIndex0':i,'exactSourceCells':row,'timeCellBBox':table.rows[i].cells[8],'roomCellBBox':table.rows[i].cells[9],'directPrintedLines':lines})
  if not aliases or any(a!=aliases[0] for a in aliases):fail.append('nativeAliasPerMeetingRoomClockMismatch')
  proof={'sourceId':c['sourceId'],'printedGeometryRows':rr,'sourceGaps':sorted(set(fail)),'eligible':not fail,'originalNativeFieldsUnchanged':True,'actualAttendanceConfirmed':False,'individualCurrentClosureWholeConfirmed':False}
  receipts.append(proof)
  if fail:continue
  schedules=[]
  for slot in aliases[0]:
   day=datetime.date(2026,9,1)
   while day<=datetime.date(2026,12,7):
    if day.isoweekday()==slot['weekday'] and day.isoformat() not in holidays:schedules.append({**slot,'date':day.isoformat()})
    day+=datetime.timedelta(days=1)
  # Existing source ordering: native meeting group order, then ascending dates within group.
  c['schedules']=schedules;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-14'}
  note='공개 원본 시간표의 같은 인쇄 높이에 위치한 강의시간·강의실을 각 회차별로 직접 대응했습니다. 9/1~12/7 학교 정규기간의 예정 수업이며 실제 참석·개별 휴강·TIGERS 최신 변경 확정이 아닙니다. 법정휴일과 12/8~14 기말기간은 제외하며 미확정 보강은 생성하지 않습니다. 기존 보류 사유와 원문 전체는 과거 검토 기록으로 보존합니다. '
  c['remarks']=note+c.get('remarks','');c['departmentRemarks']={k:note+v for k,v in c.get('departmentRemarks',{}).items()};c['datesMeaning']='published weekly planned regular teaching through December7; printed same-Y classroom pairing; holidays and December8–14 finals held; no individual attendance or current closure assertion';c['sourceGeometryResolution']={'method':'independent original PDF cell word same-Y equality <=0.1pt; every native alias exact row retained','sourcePDFSHA256':hashlib.sha256(pdfpath.read_bytes()).hexdigest(),'proofFile':'daegu-printed-time-room-geometry-proof.json','sourceId':c['sourceId'],'recordedMediaReservationsCreated':False}
  positive.append({'sourceId':c['sourceId'],'nativePairedSlots':aliases[0],'datesBySlot':[{'slot':s,'literalPlannedDates':[x['date'] for x in schedules if all(x[k]==v for k,v in s.items())]} for s in aliases[0]],'newMeetings':len(schedules),'dateOrigin':'derived weekly native source within separately verified university regular dates; not individually printed literal dates','deliveryMode':'null/user default; no physical attendance confirmation'})
write('daegu-printed-time-room-geometry-proof.json',{'sourcePDFPath':str(pdfpath.resolve()),'sourcePDFSHA256':hashlib.sha256(pdfpath.read_bytes()).hexdigest(),'inspectedScopes':len(pending),'humanWholeReadAdded':0,'nativePrintedGeometryOnePass':True,'receipts':receipts});write('daegu-main-2026-2.native-geometry-candidate.json',candidate);write('daegu-new-scopes-independent-date-plan.json',positive)
q=load('all782-held-native-source-processing-queue.json');by={r['sourceId']:r for r in receipts};pos={r['sourceId']:r for r in positive}
for item in q:
 if item['sourceId'] in by:
  item['sourceParserHeldReasons']=by[item['sourceId']]['sourceGaps'];item['directPrintedGeometryResolved']=by[item['sourceId']]['eligible'];item['newAppointments']=pos.get(item['sourceId'],{}).get('newMeetings',0)
write('all782-held-native-source-processing-queue.json',q)
progress=load('processing-progress.json');progress['positivePendingFurtherProof']=0;progress['newMeetings']=sum(p['newMeetings'] for p in positive);progress['counts']['daegu']['newScheduledScopes']=len(positive);progress['counts']['daegu']['newMeetings']=progress['newMeetings'];progress['geometryScopesOnePass']=len(pending);progress['geometryStillHeld']=sum(not r['eligible'] for r in receipts);progress['status']='source candidate ready; SDK and integrated review pending';write('processing-progress.json',progress)
print(json.dumps({'positive':len(positive),'meetings':progress['newMeetings'],'held':[(r['sourceId'],r['sourceGaps']) for r in receipts if not r['eligible']]},ensure_ascii=False))
