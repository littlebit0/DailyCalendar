import html,json,re,urllib.parse,urllib.request,hashlib
from pathlib import Path
P=Path(__file__).parent;D=P/'nsu-current-20261008';BASE='https://nsu.ac.kr';H={'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded'}
def get(url,fields=None):
 with urllib.request.urlopen(urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode() if fields else None,headers=H),timeout=40)as r:return r.read()
def clean(s):
 s=html.unescape(re.sub('<[^>]*>',' ',s or ''));s=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|\b0(?:10|2|[3-6][1-5])-?\d{3,4}-?\d{4}\b','[contact omitted]',s);return s.strip()
def save(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
manifest=[]
for id in [102709,103412]:
 data=json.loads(get(BASE+'/api/board/getBoardContent',{'id':id}));r=data['body'];assert data['code']==10000 and not r.get('is_private') and r.get('is_readable',1)
 safe={k:r[k]for k in ['id','title','registered_date','last_modified_date','is_private','is_readable','is_available','is_deleted']if k in r};safe['publicBodyText']=clean(r.get('body'));safe['attachments']=[{k:a[k]for k in ['original_filename','content_type','size','url']if k in a}for a in r.get('attachment_list',[])];save(f'central-notice-{id}.json',safe)
 for n,a in enumerate(safe['attachments']):
  if id==103412 or ('학사일정'in a['original_filename']and a['original_filename'].endswith('.xlsx')):
   name='closure-2026-2.xls'if id==103412 else 'calendar-2026-2.xlsx';b=get(BASE+'/api/file/get?'+urllib.parse.urlencode({'path':a['url']}));(D/name).write_bytes(b);manifest.append({'file':name,'noticeId':id,'originalFilename':a['original_filename'],'url':BASE+'/api/file/get?'+urllib.parse.urlencode({'path':a['url']}),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()});print(name,len(b),flush=True)
for id in [102907,102924,103137]:
 d=json.loads((D/f'notice-{id}.json').read_text()); choices=[(BASE+x,Path(urllib.parse.unquote(x)).suffix)for x in d.get('inlinePublicFilePaths',[])]+[(BASE+'/api/file/get?'+urllib.parse.urlencode({'path':a['url']}),Path(a['url']).suffix)for a in d['attachments']if '대학원'not in a['original_filename']]
 for n,(url,ext)in enumerate(choices):
  name=f'notice-{id}-file{n}{ext}';b=get(url);(D/name).write_bytes(b);manifest.append({'file':name,'noticeId':id,'url':url,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()});print(name,len(b),flush=True)
save('acquired-file-manifest.json',manifest)
