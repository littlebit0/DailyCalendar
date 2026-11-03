"""Anonymous published course plans; educational fields only, no contacts/session storage."""
import html,json,re,time,urllib.request,urllib.parse,pathlib
from acquire_postech_details import Details, KEEP
KEEP.update({'Course No.','Section','Credit','Category','Hours','Grading Scale','강의시간'})
ROOT=pathlib.Path(__file__).resolve().parent
OUT=ROOT/'postech-2026-2-public-plan-audit.json'
HEAD={'User-Agent':'Mozilla/5.0','Referer':'https://plms.postech.ac.kr/local/ubion/course/lists.php'}
def text(fragment):
 fragment=re.sub(r'<(?:script|style)\b.*?</(?:script|style)>','',fragment,flags=re.S|re.I)
 fragment=re.sub(r'<br\s*/?>|</(?:p|div|tr|li)>','\n',fragment,flags=re.I)
 value=html.unescape(re.sub('<[^>]+>',' ',fragment))
 lines=[]
 for line in value.splitlines():
  line=' '.join(line.split())
  if line and not re.search(r'@|연락처|전화번호|핸드폰|0\d{1,2}[- ]\d{3,4}[- ]\d{4}|https?://',line):lines.append(line)
 return '\n'.join(lines)
def fetch(url):
 with urllib.request.urlopen(urllib.request.Request(url,headers=HEAD),timeout=40) as r:
  if r.url.split('?')[0].endswith('/login/index.php'):return None
  return r.read().decode('utf-8')
def save(a):
 tmp=OUT.with_suffix('.tmp');tmp.write_text(json.dumps(a,ensure_ascii=False,indent=2));tmp.replace(OUT)
a={'researchOnly':True,'completionClaim':False,'term':'2026-2','scope':'All418publicundergraduate offerings','reports':[],'stopped':False}
rows=json.loads((ROOT/'postech-2026-2-undergraduate.json').read_text())
try:
 previous=json.loads(OUT.read_text()) if OUT.exists() else {'reports':[]}
 existing={(r['code'],r['section']):r for r in previous['reports'] if r.get('identityMatches')}
 for n,row in enumerate(rows,1):
  if (row['code'],row['section']) in existing:
   a['reports'].append(existing[(row['code'],row['section'])]);continue
  record={'code':row['code'],'section':row['section'],'sourceDetailUrl':row['detailUrl']}
  detail=fetch(row['detailUrl']);time.sleep(.6)
  links=re.findall(r'href=[\"\']([^\"\']*syllabusV\.php\?[^\"\']+)[\"\']',detail or '')
  if not links:record['status']='noPublicPlanLink'
  else:
   url=urllib.parse.urljoin(row['detailUrl'],html.unescape(links[0]));record['sourcePlanUrl']=url;body=fetch(url)
   if body is None:record['status']='publicLinkRequiresLoginNotAccessed'
   else:
    heading=re.search(r'<h3[^>]*>(.*?)</h3>',body,re.S);title=text(heading[1]) if heading else ''
    record['header']=title
    d=Details();d.feed(body)
    termMatch='2026년도 2학기' in title or title.startswith('2026-Fall ')
    courseMatch=(d.data.get('학수번호',d.data.get('Course No.')),d.data.get('분반',d.data.get('Section'))) == (row['code'],row['section'])
    record['identityMatches']=termMatch and courseMatch
    record['listedProfessorPresent']=row['professor'].strip() in text(body) if row['professor'].strip() else None
    if not record['identityMatches']:record['status']='identityNotVerified'
    else:
     record['educationalFields']=d.data
     sections={}
     for label,fragment in re.findall(r'<h4[^>]*>(.*?)</h4>(.*?)(?=<h4\b|$)',body,re.S):
      label=text(label)
      if not re.search(r'^\s*(?:3|4|8|9|10)\.',label):continue
      sections[label]=text(fragment)[:14000]
     record['publicOperatingSections']=sections;record['status']='publicCurrentPlanMatched'
  a['reports'].append(record);save(a);time.sleep(.6)
  if n%50==0:print('Plans',n,'of',len(rows),flush=True)
 a['all418Checked']=True;save(a);print('Finished',len(rows),'publicplans',flush=True)
except Exception as e:
 a['stopped']=True;a['failureType']=type(e).__name__;a['failure']='Normalpublicrequestfailed; no bypass or private exception text persisted';save(a);print('Stopped after',len(a['reports']),type(e).__name__,flush=True);raise SystemExit(1)
