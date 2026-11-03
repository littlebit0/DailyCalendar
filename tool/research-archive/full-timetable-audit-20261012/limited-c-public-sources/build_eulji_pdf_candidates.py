import pdfplumber,json,pathlib,re,hashlib,collections
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources');receipts=json.load(open(p/'eulji-attachment-receipts.json'));out=[];held=[]
def norm(s):return re.sub(r'\s+','',s or'')
# Read visually from the native PDF render. Older line/room objects interfere with table extraction in this single medical-engineering row; explicit columns are anchored by the independently intact professor/room rows8/9.
med7={5:'사회봉사',6:'인성과미래설계Ⅱ',10:'인성과미래설계Ⅱ',13:'사회봉사',14:'디지탈생체신호처리',18:'사회봉사',19:'인성과미래설계Ⅱ',20:'인성과미래설계Ⅱ',21:'사회봉사',26:'사회봉사',30:'인성과미래설계Ⅱ',31:'생체재료',39:'의용전자회로실험(001)',41:'의용전자회로실험(002)',44:'스마트의료센서기술실습',51:'의용전자회로',55:'스마트의료센서기술'}
for rid,dept in [('98192','의료공학과'),('98287','방사선학과')]:
 rec=next(r for r in receipts if r['id']==rid)
 with pdfplumber.open(rec['file'])as doc:
  pa=doc.pages[0];t=pa.find_tables()[0];rows=t.extract();day=None;daycols={};grade=None;cl=None
  for ci,h in enumerate(rows[0]):
   if h in ['월','화','수','목','금']:day=h
   if day:daycols[ci]=day
  for ri,row in enumerate(rows):
   if ri<2:continue
   if row[0]and re.fullmatch('[1-4]',row[0]):grade=row[0]
   if row[1]in['A','B']:cl=row[1]
   iscourse=norm(row[2])=='과목'or(rid=='98192'and ri==7)
   if not iscourse:continue
   active={ci:v for ci,v in enumerate(row)if ci>=3 and v and not re.fullmatch(r'\d+',v.strip())}
   if rid=='98192'and ri==7:active=med7
   if rid=='98192'and ri==5:
    for c in(21,22,23):active.pop(c,None) # native yellow annotation banner, not another offering
   for ci,raw in active.items():
    cell=t.rows[ri].cells[ci]
    manual=rid=='98192'and ri==7
    if manual:
     # Current separate field boundaries are published in professor row8, with same columns in classroom row9.
     cell=t.rows[8].cells[ci]
    if not cell:continue
    x0,y0,x1,y1=cell
    if manual:y0,y1=t.rows[7].cells[5][1],t.rows[8].cells[ci][1]
    covered=[j for j,b in enumerate(t.rows[1].cells)if b and (b[0]+b[2])/2>=x0-0.1 and(b[0]+b[2])/2<x1-0.1]
    periods=[rows[1][j]for j in covered];days={daycols.get(j)for j in covered};reason=None
    bottom=ri
    if not manual:
     for rr in range(ri,len(rows)):
      b=next((b for b in t.rows[rr].cells if b and abs(b[0]-x0)<.2 and abs(b[2]-x1)<.2 and abs(b[3]-y1)<.2),None)
      if b and abs(b[1]-y0)<.2:bottom=rr
      # merged cells appear only at first anchor; row y bounds from label column identify the bottom logically.
      if t.rows[rr].cells[2]and t.rows[rr].cells[2][1]<y1-.1:bottom=rr
    pr=8 if manual else bottom+1;cr=9 if manual else bottom+2
    prof='';room=''
    if pr<len(rows)and cr<len(rows)and norm(rows[pr][2])=='교수명'and norm(rows[cr][2])=='강의실':
     def field(rr):
      for j,b in enumerate(t.rows[rr].cells):
       if b and b[0]-.2<=x0 and b[2]+.2>=x1:return norm(rows[rr][j])
      return ''
     prof=field(pr);room=field(cr)
    title=norm(raw);section=''
    sm=re.search(r'(?:\(|-)(\d{3})\)?$',title)
    if sm:section=sm[1];title=title[:sm.start()]
    if rid=='98287'and ri==2 and ci==32:title='인성과대학생활Ⅱ'
    if rid=='98287'and ri==2 and ci==33:title='방사선통계와데이터'
    if any(re.search(k,title)for k in['현장실습','임상실습','임상연계','모의고사']):reason='Clinical/placement/exam context; ordinary weekly operation not established.'
    if '심폐소생술'in title:reason='Native10–14weeks/5week block; exact phase dates not established.'
    if not periods or len(days)!=1 or None in days or any(not re.fullmatch('[1-9]',n or'')for n in periods):reason='Night/unsupported period; publisheddayclock1–9 only.'
    if re.search(r'을\d+|박\d+|범\d+',title):reason='Interfering prior room/text objects; no inferred course title.'
    d=next(iter(days))if len(days)==1 else'';nums=[int(n)for n in periods if re.fullmatch('[1-9]',n or'')]
    sched=[{'weekday':'월화수목금'.index(d)+1,'startMinute':480+60*min(nums),'endMinute':480+60*max(nums)+50,'classroom':room}]if not reason else[]
    loc={'downloadFileId':rid,'pdfPage':1,'table':0,'row':ri,'column':ci,'box':[x0,y0,x1,y1],'sourceGrade':grade,'sourceClass':cl,'visualTitleReviewed':manual or(rid=='98287'and ri==2 and ci in[32,33])}
    identity=f'{rid}/page1/table0/row{ri}/column{ci}';c={'sourceId':'eulji/seongnam/2026/2/'+hashlib.sha256(identity.encode()).hexdigest()[:24],'universityId':'eulji','campus':'seongnam','campusName':'성남캠퍼스','academicYear':2026,'semester':'2','courseCode':'','courseName':title,'section':section,'professor':prof,'departments':[dept],'departmentCredits':{},'departmentClassifications':{dept:''},'departmentRemarks':{dept:'공식학과교육시간표조회소속; 코드및개설주관원문미표기'},'schedules':sched,'scheduleStatus':'unrecognized'if reason else'scheduled','sourceUrl':rec['noticeUrl'],'sourceSchedule':f'{d} '+','.join(periods),'sourceClassroom':room,'sourceLocator':loc,'sourceGrade':grade,'sourceClass':cl,'nativeCourseText':raw,'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}}
    if reason:held.append({'sourceId':c['sourceId'],'locator':loc,'reason':reason})
    out.append(c)
(p/'eulji-two-pdf-source-candidate.json').write_text(json.dumps({'schemaVersion':2,'universityId':'eulji','campus':'seongnam','academicYear':2026,'semester':'2','sourceRowCount':len(out),'courses':out,'held':held,'completionClaim':False,'sourceReview':'Native PDF renders viewed; medical row7 professor/room native boundaries anchor visual title corrections. No title-only merge.'},ensure_ascii=False,indent=2));print('PDF nodes',len(out),collections.Counter(c['scheduleStatus']for c in out))
