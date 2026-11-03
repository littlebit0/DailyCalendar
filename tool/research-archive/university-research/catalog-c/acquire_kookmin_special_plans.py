"""Actual public report button protocol, identifiers/whole reports kept memory only."""
import urllib.request,urllib.parse,json,base64,re,http.cookiejar,time
from pathlib import Path
P=Path(__file__).resolve().parent
rows=json.loads((P/'kookmin-special-operating-course-candidates.json').read_text())
rows += json.loads((P/'kookmin-current-unmapped-department-courses.json').read_text())['records']
rows += [r for r in json.loads((P/'kookmin-current-college-scope.json').read_text())['records'] if r['subjectId'] in ['1095100','1095200','1131900','1231701','0716902','0395402','0504202'] and r['courseCode']=='00' and not r['closed']]
headers={'User-Agent':'Mozilla/5.0','Referer':'https://sugang.kookmin.ac.kr/front/enrollment/course-catalog','Accept':'*/*','X-Requested-With':'XMLHttpRequest'}
def req(op,url,data):
 time.sleep(.6)
 return op.open(urllib.request.Request(url,data=urllib.parse.urlencode(data).encode(),headers=headers),timeout=40).read()
def texts(x):
 if isinstance(x,dict):
  for v in x.values():yield from texts(v)
 elif isinstance(x,list):
  for v in x:yield from texts(v)
 elif isinstance(x,str):
  t=urllib.parse.unquote_plus(x)
  if re.search('[가-힣]|\d{1,2}[./월]\s*\d{1,2}',t):
   if any(z in t for z in ['@','담당교수','교수명','전화','연락처','이메일','연구실','교수번호','교번','reportkey']):return
   t=re.sub(r'\b[0-9a-fA-F]{24,}\b','[removed]',t)
   t=re.sub(r'\b\d{7,}\b','[removed]',t)
   t=re.sub(r'(?:0\d{1,2}[- ]\d{3,4}[- ]\d{4})','[contact removed]',t)
   if len(t)>20000:return
   yield t
out=[];dest=P/'kookmin-special-public-plans-education.json'
if dest.exists():out=json.loads(dest.read_text())
done={(x['subjectId'],x['section']) for x in out}
for r in rows:
 sid=r['subjectId'];sec=r['classSequence']
 if (sid,sec) in done:continue
 op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
 try:
  params={'mlangCd':'ko','reportList':'20262020000'+sid+sec,'loginYn':'0'}
  data={'filePath':'sch/sles/slesfm/slesfm0340_prn03','paramType':'query','reportBtn':'PEH','reportParams':base64.b64encode(json.dumps(params,separators=(',',':')).encode()).decode()}
  html=req(op,'https://kep.kookmin.ac.kr/report/callReport.jsp',data).decode();key=re.search(r"'uid':'([^']+)'",html).group(1)
  for i in range(15):
   check=json.loads(req(op,'https://kep.kookmin.ac.kr/report/report_server.jsp',{'ClipType':'pageCheck','ClipData':json.dumps({'reportkey':key,'s_time':'t'+str(i)})}))
   if check.get('resValue',{}).get('endReport'):break
  else:raise TimeoutError('report not completed')
  data=json.loads(req(op,'https://kep.kookmin.ac.kr/report/report_server.jsp',{'ClipType':'DocumentPageOnly','ClipData':json.dumps({'reportkey':key,'pageMethod':'TotalPage','isMakeDocument':True})}))
  view=json.loads(base64.b64decode(data['resValue']['viewData']));ss=list(dict.fromkeys(texts(view)))
  term=any('2026학년도' in x and '2학기' in x for x in ss)
  out.append({'subjectId':sid,'section':sec,'title':r['subjectNm'],'current2026-2Header':term,'educationalText':ss,'status':'obtained'})
 except Exception as e:
  out.append({'subjectId':sid,'section':sec,'title':r['subjectNm'],'status':'unverified','errorType':type(e).__name__})
 dest.write_text(json.dumps(out,ensure_ascii=False,indent=2));print(sid,sec,out[-1]['status'],flush=True)
