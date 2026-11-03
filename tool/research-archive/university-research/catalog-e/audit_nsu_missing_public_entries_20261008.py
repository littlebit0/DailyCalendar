import html,json,re,urllib.request,urllib.parse
from pathlib import Path
D=Path(__file__).parent/'nsu-current-20261008';BASE='https://nsu.ac.kr';result=[]
a=json.loads((D/'department-scope-audit.json').read_text())
def get(url,fields=None):
 with urllib.request.urlopen(urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode()if fields else None,headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded'}),timeout=30)as r:return r.read().decode('utf-8'),r.url
for row in a['results']:
 if not row['errors'] and row.get('noticeBoardIds'):continue
 o={'name':row['department'],'entry':row['entry']}
 try:
  source,o['finalUrl']=get(row['entry']);o['title']=html.unescape(re.search(r'<title[^>]*>(.*?)</title>',source,re.S)[1]).strip();o['publishedTimetableLinks']=[{'url':html.unescape(u),'text':html.unescape(re.sub('<[^>]*>','',t)).strip()}for u,t in re.findall(r'<a[^>]+href=[\"\x27]([^\"\x27]+)[\"\x27][^>]*>(.*?)</a>',source,re.S)if re.search('시간표|수강|공지|학사',t)]
  m=re.search(r'var MENU_LIST = ',source)
  if m:
   menus=json.JSONDecoder().raw_decode(source[m.end():])[0];o['publishedBoardMenus']=[]
   def walk(items):
    for item in items:
     if item.get('content',{}).get('type_code')==6:
      data,_=get(urllib.parse.urljoin(o['finalUrl'],'/api/website/getMenu'),{'id':item['id']});data=json.loads(data).get('body',{});o['publishedBoardMenus'].append({'id':item['id'],'title':item['title'],'responseTitle':data.get('title'),'nativeTitleMatches':data.get('title')==item['title'],'content': {'type_code':data.get('content',{}).get('type_code'),'data': {k:v for k,v in data.get('content',{}).get('data',{}).items() if k in {'id','type_code'}} if isinstance(data.get('content',{}).get('data'),dict) else None}})
     walk(item.get('child_list',[]))
   walk(menus.get('list',[]))
 except Exception as e:o['error']=str(e)
 result.append(o);print(o['name'],o.get('title'),len(o.get('publishedBoardMenus',[])),o.get('error'),flush=True)
(D/'missing-entry-path-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
