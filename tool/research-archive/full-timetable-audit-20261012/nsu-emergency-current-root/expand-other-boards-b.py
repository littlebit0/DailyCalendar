import json,pathlib,re,urllib.request,urllib.parse,concurrent.futures,hashlib
P=pathlib.Path(__file__).parent;OLD=pathlib.Path('work/university-research/catalog-e/nsu-current-20261008')
entries=json.load(open(OLD/'department-scope-audit.json'))['normalPublishedDepartmentEntries'];covered={'응급구조학과','영어과','건축공학과','스마트팜학과'}
def req(url,fields=None):
 r=urllib.request.urlopen(urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode() if fields else None),timeout=18);return r.read(),r.url
# Existing confirmed identical source, no duplicate transcription.
(P/'emt-identical-source.json').write_text(json.dumps({'sameBytes':(P/'emt-2026fall-undergraduate.pdf').read_bytes()==(OLD/'notice-102924-file0.pdf').read_bytes(),'sha256':hashlib.sha256((P/'emt-2026fall-undergraduate.pdf').read_bytes()).hexdigest(),'reuseExistingCourses':26},indent=2))
def task(e):
 url,name=e;o={'department':name,'entry':url,'boards':[],'errors':[]}
 if name in covered:o['skip']='existing covered timetable department';return o
 try:
  b,final=req(url);s=b.decode('utf-8');o['finalUrl']=final;m=re.search(r'var MENU_LIST = ',s)
  safe=urllib.parse.urlparse(final).hostname or name;(P/(safe+'-home.html')).write_bytes(b)
  if not m:o['otherSystem']='No MENU_LIST; actual links saved';return o
  menus=json.JSONDecoder().raw_decode(s[m.end():])[0]
  def walk(items):
   for item in items:
    title=item.get('title','')
    if item.get('content',{}).get('type_code')==6 and re.search('공지|자료|수강|시간표|학사|교과',title):
     mb,_=req(urllib.parse.urljoin(final,'/api/website/getMenu'),{'id':item['id']});md=json.loads(mb).get('body',{});(P/(safe+'-menu-'+str(item['id'])+'.json')).write_bytes(mb)
     if md.get('title')!=title:continue
     data=md.get('content',{}).get('data',{});bid=data.get('id') if isinstance(data,dict) else None
     if not bid:continue
     binfo={'menuId':item['id'],'title':title,'boardId':bid,'notices':[]}
     # Native page count=10, first five pages; actual website request fields only.
     for pg in range(1,6):
      fields={'boardIdList':bid,'isAvailable':1,'isDeleted':0,'parentBoardContentId':-1,'page':pg,'count':10,'includeBody':1,'includeAttachmentList':1}
      nb,_=req(urllib.parse.urljoin(final,'/api/user/board/getBoardContentSummaryList'),fields);(P/(safe+'-board-'+str(bid)+'-p'+str(pg)+'.json')).write_bytes(nb);nd=json.loads(nb);nl=nd.get('body',{}).get('list',[])
      for n in nl:
       if re.search('시간표|수강|개설',n.get('title','')):binfo['notices'].append({k:n.get(k) for k in ['id','title','registered_date','last_modified_date','is_private','is_readable','attachment_count']})
      if not nl:break
     o['boards'].append(binfo)
    walk(item.get('child_list',[]))
  walk(menus.get('list',[]))
 except Exception as e:o['errors'].append(str(e))
 return o
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
 for o in ex.map(task,entries):
  results.append(o);(P/'other-department-board-audit-b.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print(o['department'],sum(len(b['notices']) for b in o['boards']),o['errors'],flush=True)
