import html,json,re,urllib.request,urllib.parse
from pathlib import Path
D=Path(__file__).parent/'nsu-current-20261008'
def get(base,path,params):
 with urllib.request.urlopen(urllib.request.Request(urllib.parse.urljoin(base,path),data=urllib.parse.urlencode(params).encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded'}),timeout=30)as r:return json.loads(r.read())
def save(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def safe(r):return {k:r[k]for k in ['id','title','registered_date','last_modified_date','is_private','is_readable','is_available','is_deleted']if k in r}
def clean(s):
 s=html.unescape(re.sub('<[^>]*>',' ',s or ''));return re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|\b0(?:10|2|[3-6][1-5])[-.) ]*\d{3,4}[-. ]*\d{4}\b','[contact omitted]',s).strip()
results=[]
for item in json.loads((D/'missing-entry-path-audit.json').read_text()):
 for menu in item.get('publishedBoardMenus',[]):
  if menu['title']!='공지사항'or not menu['nativeTitleMatches']or not isinstance(menu['content'].get('data'),dict):continue
  board=menu['content']['data'].get('id');out={'name':item['name'],'entry':item['finalUrl'],'menuId':menu['id'],'boardId':board,'notices':[]};seen=set()
  try:
   for page in range(1,6):
    d=get(item['finalUrl'],'/api/user/board/getBoardContentSummaryList',{'boardIdList':board,'isDeleted':0,'isAvailable':1,'parentBoardContentId':-1,'page':page,'count':10,'includeBody':1});assert d['code']==10000
    body=d.get('body',{});out['totalNoticeCount']=body.get('total_count')
    for r in body.get('list',[]):
     if r.get('is_private')or not r.get('is_readable',1)or r['id']in seen:continue
     seen.add(r['id']);out['notices'].append(safe(r));title=r.get('title')or''
     if re.search('2026|26학',title)and re.search('시간표|수강|개설|폐강|강의',title):
      row=get(item['finalUrl'],'/api/board/getBoardContent',{'id':r['id']})['body']
      if row.get('is_private')or not row.get('is_readable',1):continue
      source=row.get('body')or'';safeRow={**safe(row),'departmentScope':item['name'],'sourceDomain':item['finalUrl'],'publicBodyText':clean(source),'inlinePublicFilePaths':[html.unescape(x)for x in re.findall(r'(?:src|href)=\"(/api/file/get[?]path=[^\"]+)\"',source)],'attachments':[{k:a[k]for k in ['original_filename','content_type','size','url']if k in a}for a in row.get('attachment_list',[])]};save('recovered-'+str(r['id'])+'.json',safeRow)
    if page*10>=body.get('total_count',0):break
  except Exception as e:out['error']=str(e)
  results.append(out);print(out['name'],len(out['notices']),out.get('error'),flush=True)
save('recovered-board-audit.json',results)
