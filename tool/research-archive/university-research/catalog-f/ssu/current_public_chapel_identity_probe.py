"""Normal anonymous public SAP controls, educational values only; no raw session saved."""
from urllib.request import build_opener,HTTPCookieProcessor,Request
from urllib.parse import urlencode,urljoin,urlsplit
from http.cookiejar import CookieJar
from html.parser import HTMLParser
from pathlib import Path
import re,html,json,hashlib,time
R=Path(__file__).resolve().parent;URL='https://ecc.ssu.ac.kr/sap/bc/webdynpro/sap/zcmw2100?sap-language=KO'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
op=build_opener(HTTPCookieProcessor(CookieJar()));HEAD={'User-Agent':UA,'Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8','Accept-Language':'ko-KR,ko;q=0.9,en;q=0.7'};requests=[]
def read(url,payload=None):
 req=Request(url,data=payload,headers=HEAD if payload is None else dict(HEAD,Referer=URL,Origin=urlsplit(URL).scheme+'://'+urlsplit(URL).netloc,**{'X-Requested-With':'XMLHttpRequest','X-XHR-Logon':'accept','Content-Type':'application/x-www-form-urlencoded'}))
 with op.open(req,timeout=25) as q:
  b=q.read()
  if q.status in [401,403,429]:raise RuntimeError('Protective response stop')
 if any(v in b.lower() for v in [b'captcha',b'access denied',b'too many requests']):raise RuntimeError('Protective response stop')
 requests.append({'responseSHA256':hashlib.sha256(b).hexdigest(),'bytes':len(b)});time.sleep(.8);return b.decode()
def content(t):return ''.join(re.findall(r'<!\[CDATA\[(.*?)\]\]>',t,re.S)) if t.lstrip().startswith('<updates') else t
action=URL;data={}
def form(t):
 global action,data
 f=re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>',content(t),re.S)
 if f:
  action=urljoin(URL,html.unescape(f[1]));data={html.unescape(k):html.unescape(v) for k,v in re.findall(r'name="([^"]+)" value="([^"]*)"',f[2])}
def event(control,name,params):
 global b
 form(b);ev=control+'_'+name+'\ue002'+'\ue005'.join(k+'\ue004'+str(v) for k,v in params.items())+'\ue003\ue002ResponseData\ue004delta\ue005ClientAction\ue004submit\ue003\ue002\ue003'
 data['SAPEVENTQUEUE']=''.join(c if c.isascii() and(c.isalnum() or c in '-_.') else '~'+format(ord(c),'04X') for c in ev)
 b=read(action,urlencode(data).encode());return b
class Controls(HTMLParser):
 def __init__(self):super().__init__();self.rows=[]
 def handle_starttag(self,t,a):
  d=dict(a)
  if d.get('ct') in ['CB','B','I','TSITM_standards','LIB_I']:self.rows.append(d)
def controls(t):
 p=Controls();p.feed(content(t));return p.rows
def education(t):
 text=content(t);hs=[];out=[]
 for th in re.findall(r'<th\b[^>]*role="columnheader"[^>]*>(.*?)</th>',text,re.S):
  v=re.search(r'ct="CP"[^>]*>(.*?)</span>',th,re.S);hs.append(html.unescape(re.sub('<[^>]+>',' ',v[1] if v else th)).strip())
 if '과목번호' not in hs:raise RuntimeError('No public course table')
 for tr in re.findall(r'<tr\b[^>]*>(.*?)</tr>',text,re.S):
  vals=[html.unescape(re.sub('<[^>]+>',' ',q)).replace('\xa0',' ').strip() for q in re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>',tr,re.S)]
  if len(vals)==len(hs):
   row=dict(zip(hs,vals))
   if re.fullmatch(r'\d{10}',row.get('과목번호','')):out.append(row)
 return out
b=read(URL);form(b);print('published form input keys',sorted(data));event('LoadingPlaceHolder','Load',{'Id':'_loadingPlaceholder_'})
c=controls(b)
years=[q.get('value','') for q in c if q.get('ct')=='CB' and '학년도' in q.get('value','')]
if not years:
    print('No published year selector; controls',len(c),'responseBytes',len(b),'title',re.findall(r'<title>(.*?)</title>',b,re.S),'uiMessages',[v for v in ['Session','error','Error','오류','로그인','지연','대기'] if v in b]);raise RuntimeError('Stop before unpublished or protected controls')
year=years[0];term=next(q['value'] for q in c if q.get('ct')=='CB' and q.get('value') in ['1학기','2학기']);assert year=='2026학년도' and term=='2학기'
tab=next(q for q in c if q.get('ct')=='TSITM_standards' and "2:'채플'" in q.get('lsdata',''));index=re.search(r'1:(\d+)',tab['lsdata'])[1]
strip=next(re.findall(r'id="([^"]+)"[^>]*ct="TS_standards"',content(b)).__iter__())
event('TabStrip','TabSelect',{'Id':strip,'ItemId':tab['id'],'ItemIndex':index,'FirstVisibleItemIndex':0})
c=controls(b);chooser=[q for q in c if q.get('ct')=='CB' and q['id'] not in ['WD92','WDE6','WD015D']];assert len(chooser)==1
choice=next(q for q in c if q.get('ct')=='LIB_I' and '소그룹채플' in q.get('data-itemvalue1',''))
event('ComboBox','Select',{'Id':chooser[0]['id'],'Key':choice['data-itemkey'],'ByEnter':'false'})
button=next(q for q in controls(b) if q.get('ct')=='B' and "0:'검색'" in q.get('lsdata',''));event('Button','Press',{'Id':button['id']})
rows=education(b);assert rows
(R/'ssu-current-public-smallgroup-chapel-education-20261008.json').write_text(json.dumps({'currentYear':year,'currentTerm':term,'rows':rows},ensure_ascii=False,indent=2)+'\n')
(R/'ssu-current-public-smallgroup-chapel-normal-flow-audit-20261008.json').write_text(json.dumps({'normalPublishedControlsOnly':True,'loginOrPrivateAccess':False,'rawAnonymousStateSaved':False,'requests':requests,'rows':len(rows),'currentYear':year,'currentTerm':term},indent=2)+'\n')
print('current public course rows',len(rows),'ids',[q['과목번호'] for q in rows])
