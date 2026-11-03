import json,pathlib,re,zipfile,xml.etree.ElementTree as E,hashlib,collections
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources');receipts=json.load(open(p/'eulji-attachment-receipts.json'));ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
def col(s):
 out=0
 for c in s:out=out*26+ord(c)-64
 return out
def coords(s):
 a,b=re.fullmatch(r'([A-Z]+)(\d+)',s).groups();return col(a),int(b)
allc=[];hold=[]
for rid,dept in [('98200','시각디자인전공'),('97938','장례지도학과'),('97462','임상병리학과')]:
 rec=next(r for r in receipts if r['id']==rid);f=pathlib.Path(rec['file']);z=zipfile.ZipFile(f);ss=[''.join(e.itertext())for e in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)]
 for sh in [n for n in z.namelist()if n.startswith('xl/worksheets/sheet')and n.endswith('.xml')]:
  root=E.fromstring(z.read(sh));cells={};names={};ranges=[]
  for c in root.findall('.//m:c',ns):
   v=c.find('m:v',ns)
   if v is None:continue
   val=ss[int(v.text)]if c.attrib.get('t')=='s'else v.text;xy=coords(c.attrib['r']);cells[xy]=val;names[xy]=c.attrib['r']
  for r in root.findall('.//m:mergeCell',ns):
   a,b=r.attrib['ref'].split(':');ranges.append((coords(a),coords(b),r.attrib['ref']))
  expanded=dict(cells)
  for (x,y),(xx,yy),ref in ranges:
   if(x,y)in cells:
    for tx in range(x,xx+1):
     for ty in range(y,yy+1):expanded[(tx,ty)]=cells[(x,y)]
  daycols={x:val for(x,y),val in expanded.items()if y==3 and val in['월','화','수','목','금']};periodcols={x:int(val)for(x,y),val in expanded.items()if y==4 and re.fullmatch('[1-9]',val)}
  for(x,y),val in cells.items():
   if x<4 or expanded.get((3,y),'').replace('\xa0','').replace(' ','')!='과목':continue
   day=daycols.get(x);first=periodcols.get(x)
   if not day or not first:continue
   merge=next(((a,b,ref)for a,b,ref in ranges if a==(x,y)),None);endx=merge[1][0]if merge else x;last=periodcols.get(endx);sourcecell=names[(x,y)]
   title=re.sub(r'\([^\)]*\)','',val);title=title.splitlines()[0].strip()
   # Multi-line wrapped title is preserved exactly; remove only explicit native IDs/classification/credit metadata.
   titlelines=[]
   for line in val.splitlines():
    if re.fullmatch(r'\s*\(?[\d/-]+\)?\s*',line)or re.fullmatch(r'\s*(?:교양필수|교양선택|전공기초|전공필수|전공선택|교필|교선|전필|전선)\s*',line):continue
    titlelines.append(re.sub(r'교양필수|교양선택|전공기초|전공필수|전공선택|교필|교선|전필|전선','',re.sub(r'\((?:임상)?\d{3,6}(?:-\d{3})?\)','',line)).strip())
   title=' '.join(titlelines).strip();ident=re.search(r'\((\d{6})-(\d{3})\)',val);sect=re.search(r'\((?:임상)?(\d{3})\)',val);code=ident[1]if ident else'';section=ident[2]if ident else(sect[1]if sect else'')
   endrow=merge[1][1]if merge else y;profrow=endrow+1;roomrow=endrow+2;verticalResolvable=expanded.get((3,profrow),'')=='교수명'and expanded.get((3,roomrow),'')=='강의실';prof=expanded.get((x,profrow),'')if verticalResolvable else'';room=expanded.get((x,roomrow),'')if verticalResolvable else'';classification=next((c for c in ['교양필수','교양선택','전공기초','전공필수','전공선택','교필','교선','전필','전선']if c in val),'')
   vertical=bool(merge and merge[1][1]>y);partial=bool(re.search(r'\d+\s*[~～-]\s*\d+\s*주|\d+주차',val));status='scheduled'if last and daycols.get(endx)==day and not partial and (not vertical or verticalResolvable) else'unrecognized'
   ssched=[{'weekday':'월화수목금'.index(day)+1,'startMinute':480+60*first,'endMinute':480+60*last+50,'classroom':room}]if status=='scheduled'else[]
   identity=f'{rid}/{sh}/{sourcecell}';c={'sourceId':'eulji/seongnam/2026/2/'+hashlib.sha256(identity.encode()).hexdigest()[:24],'universityId':'eulji','campus':'seongnam','campusName':'성남캠퍼스','academicYear':2026,'semester':'2','courseCode':code,'courseName':title,'section':section,'professor':prof,'departments':[dept],'departmentCredits':{},'departmentClassifications':{dept:classification},'departmentRemarks':{dept:'공식 학과 시간표 조회 소속; 학과 주관 여부 미확정'},'schedules':ssched,'scheduleStatus':status,'sourceUrl':rec['noticeUrl'],'sourceSchedule':f'{day} {first}~{last}교시','sourceClassroom':room,'nativeCells':{'course':val,'professor':prof,'classroom':room},'sourceGrade':expanded.get((1,y),''),'sourceClassCoverage':sorted(set(expanded.get((2,cy),'')for cy in range(y,endrow+1)if expanded.get((3,cy),'').replace('\xa0','').replace(' ','')=='과목')),'sourceClass':expanded.get((2,y),''),'sourceLocator':{'downloadFileId':rid,'sheet':sh,'cell':sourcecell,'mergedRange':merge[2]if merge else None},'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}}
   if status=='unrecognized':hold.append({'sourceId':c['sourceId'],'reason':'vertical course/professor/room merged text requires manual interpretation'if vertical else'partial teaching weeks or unsupported grid boundary; no guessed schedule'})
   allc.append(c)
# Keep sourcecell identities to avoid combining unspecified sections with same title/professor.
result={'schemaVersion':2,'universityId':'eulji','campus':'seongnam','academicYear':2026,'semester':'2','sourceRowCount':len(allc),'courses':allc,'sourceUrls':[r['noticeUrl']for r in receipts if r['id']in['98200','97938','97462']],'periodClockEvidence':{'url':'https://www.anyang.ac.kr/main/communication/notice.do?mode=download&articleNo=40936&attachNo=16257','literal':'2026-2 을지대학교 학점교류 공식 안내 p1 dayperiod1–9 09:00–17:50, 수업기간9/1–12/21'},'completionClaim':False,'mergePolicy':'research candidate; do not replace existing67. Review sourcecell duplicate/unspecified section before asset integration.','held':hold}
(p/'eulji-three-department-schema2-candidate.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('sourcecell courses',len(allc),collections.Counter(c['scheduleStatus']for c in allc))
