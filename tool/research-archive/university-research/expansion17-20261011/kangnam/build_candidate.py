import json,re,hashlib,collections
from pathlib import Path
p=Path(__file__).parent
rows=json.loads((p/'native-rows.json').read_text());group=collections.defaultdict(list)
for row in rows:group[(row['native']['학수번호'],row['native']['분반'])].append(row)
courses=[];holds=[];notes=json.loads((p/'native-notes.json').read_text())
pattern=re.compile(r'([월화수목금토일])\s*(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})')
clean=lambda x:re.sub(r'\s+','',x or '')
for (code,section),native in group.items():
 conflicting=any(len({clean(x['native'].get(k,''))for x in native if x['native'].get(k,'')})>1 for k in ['교과목명','담당교수','강의시간','강의실','학점'])
 if conflicting:
  holds.append({'code':code,'section':section,'reason':'conflicting native rows','rows':native});continue
 if any('동계스포츠' in x['native']['교과목명'] for x in native):
  holds.append({'code':code,'section':section,'reason':'official guide p10 explicitly specifies off-campus intensive weekends/vacation; exact sessions unavailable','rows':native});continue
 row=dict(max(native,key=lambda x:len(x['native']))['native'])
 for k in ['교과목명','담당교수','강의시간','강의실','학점']:
  if not row.get(k):row[k]=next((x['native'][k]for x in native if x['native'].get(k)), '')
 source=row.get('강의시간','');matches=list(pattern.finditer(source));remainder=pattern.sub('',source).strip(' ,/;·')
 if not matches or remainder:
  holds.append({'code':code,'section':section,'reason':'native clock absent or unrecognized','rows':native});continue
 meetings=[]
 for m in matches:
  start=int(m[2])*60+int(m[3]);end=int(m[4])*60+int(m[5])
  if not 0<=start<end<=1440 or int(m[3])>59 or int(m[5])>59:raise ValueError(row)
  meetings.append({'weekday':'월화수목금토일'.index(m[1])+1,'startMinute':start,'endMinute':end,'classroom':row.get('강의실','')})
 depts=sorted({x['heading'].lstrip('○◎ ').strip()for x in native if any(k in x['heading']for k in ['학과','학부','전공'])})
 credits=float(row['학점']);remarks=sorted({x['native']['비고']for x in native if x['native'].get('비고')} | {n['text']for n in notes.get(f'{code}-{section}',[])})
 courses.append({'sourceId':f'kangnam-main-2026-2-{code}-{section}','campus':'main','academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':row['교과목명'],'professor':row.get('담당교수',''),'credits':credits,'classification':row['이수구분'],'departments':depts,'departmentCredits':{d:credits for d in depts},'departmentClassifications':{d:row['이수구분']for d in depts},'remarks':' / '.join(remarks),'sourceSchedule':source,'sourceClassroom':row.get('강의실',''),'period':{'startDate':'2026-09-01','endDate':'2026-12-16'},'schedules':meetings,'sourcePages':sorted({x['page']for x in native})})
url='https://app.kangnam.ac.kr/knumis/sb/sbm1050DownloadAll.jsp?schl_smst=2&schl_year=2026'
dataset={'schemaVersion':1,'universityId':'kangnam','campus':'main','campusName':'전체','academicYear':2026,'semester':'2','publishedDate':'','publishedDateUnavailable':True,'sourceUrl':url,'sourceSha256':hashlib.sha256((p/'download.raw').read_bytes()).hexdigest(),'sourceRowCount':len(rows),'sourceScope':'Official whole registration book; native untimed/conflicting rows held, not full current live availability','completionClaim':False,'periodEvidence':{'start':'2026-09-01','end':'2026-12-16','sourceUrl':'https://app.kangnam.ac.kr/knumis/sb/sbm1050Download.jsp?gubn_code=1&schl_smst=2&schl_year=2026','basis':'2학기개강9/1, 기말고사12/8–14, 보강12/15–16, 동계방학12/17'},'courses':courses}
(p/'kangnam-main-2026-2.candidate.json').write_text(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n');(p/'holds.json').write_text(json.dumps(holds,ensure_ascii=False,indent=2)+'\n')
print('candidate',len(courses),'meetings',sum(len(x['schedules'])for x in courses),'holds',len(holds),collections.Counter(x['reason']for x in holds))
