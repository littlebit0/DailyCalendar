"""Normal anonymous educational notice requests. No authentication or raw staff metadata saved."""
import concurrent.futures,html,json,re,time,urllib.parse,urllib.request
from pathlib import Path
P=Path(__file__).parent;D=P/'nsu-current-20261008';D.mkdir(exist_ok=True)
UA='Mozilla/5.0';ROOT='https://nsu.ac.kr';headers={'User-Agent':UA,'Content-Type':'application/x-www-form-urlencoded'}
def request(url,fields=None):
 q=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode() if fields else None,headers=headers)
 with urllib.request.urlopen(q,timeout=30)as r:return r.read()
def text(s):
 s=html.unescape(re.sub('<[^>]*>',' ',s));s=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[contact omitted]',s);s=re.sub(r'\b0(?:10|2|[3-6][1-5])-?\d{3,4}-?\d{4}\b','[contact omitted]',s);return s.strip()
def safe(r):return {k:r[k]for k in ['id','title','registered_date','last_modified_date','is_private','is_readable','is_available','is_deleted']if k in r}
def save(name,data):(D/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
s=(P/'nsu-home-real.html').read_text();departments=list(dict.fromkeys((html.unescape(url),text(name))for url,name in re.findall(r'<option value="(https?://[^\"]*nsu.ac.kr[^\"]*)">(.*?)</option>',s)))[:44]
departments += [(url,label)for url,label in list(dict.fromkeys((html.unescape(url),text(name))for url,name in re.findall(r'<option value="(https?://[^\"]*nsu.ac.kr[^\"]*)">(.*?)</option>',s))) if label=='교직부']
def scan(item):
 url,label=item;host=urllib.parse.urlparse(url).hostname;out={'department':label,'entry':url,'notices':[],'errors':[]}
 try:
  source=request(url).decode('utf-8');m=re.search(r'var MENU = ',source)
  if not m:out['errors'].append('no native department MENU metadata');return out
  menu=json.JSONDecoder().raw_decode(source[m.end():])[0];data=menu.get('content',{}).get('data',{});data=json.loads(data) if isinstance(data,str) else data;boards=data.get('notice_board_id_list');out['noticeBoardIds']=boards;out['menuId']=menu.get('id');out['noticeMenuId']=data.get('notice_menu_id')
  if not boards:return out
  seen=set()
  for page in range(1,6):
   d=json.loads(request(ROOT+'/api/user/board/getBoardContentSummaryList',{'boardIdList':boards,'isDeleted':0,'isAvailable':1,'parentBoardContentId':-1,'page':page,'count':10,'includeBody':1}))
   if d.get('code')!=10000:out['errors'].append({'page':page,'publicCode':d.get('code')});break
   body=d.get('body',{});out['totalNoticeCount']=body.get('total_count')
   for r in body.get('list',[]):
    if r.get('is_private') or not r.get('is_readable',1):continue
    if r['id']in seen:continue
    seen.add(r['id']);row=safe(r);out['notices'].append(row)
    if re.search('시간표|수강|개설|폐강|강의',(r.get('title') or ''))and re.search('2026|26학',(r.get('title') or '')):
     detail=json.loads(request(ROOT+'/api/board/getBoardContent',{'id':r['id']})).get('body',{})
     if detail.get('is_private') or not detail.get('is_readable',1):continue
     summary={**safe(detail),'departmentScope':label,'publicBodyText':text(detail.get('body','') or ''),'inlinePublicFilePaths':[html.unescape(x) for x in re.findall(r'(?:src|href)="(/api/file/get\?path=[^"]+)"',detail.get('body','') or '')],'attachments':[{k:a[k]for k in ['original_filename','content_type','size','url']if k in a}for a in detail.get('attachment_list',[])]}
     save(f"notice-{r['id']}.json",summary)
   if page*10>=body.get('total_count',0):break
  save('department-'+str(menu['id'])+'.json',out)
 except Exception as e:out['errors'].append(str(e))
 return out
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as pool:
 for result in pool.map(scan,departments):results.append(result);print(result['department'],len(result['notices']),result['errors'],flush=True)
save('department-scope-audit.json',{'normalPublishedDepartmentEntries':departments,'results':results,'completionClaim':False,'noLogin':True,'noVisibleUI':True,'noRawStaffMetadata':True})
