import concurrent.futures,json,urllib.request,urllib.parse,pathlib,time
out=pathlib.Path('work/university-directory')
def page(i):
 path=out/f'page{i}.json'
 if path.exists(): return json.loads(path.read_text())
 data=urllib.parse.urlencode(dict(svy_yr=2026,pageindex=i,pbnf_area_cd='',searchVal='')).encode()
 req=urllib.request.Request('https://m.academyinfo.go.kr/intro/intro0350/selectSchlListAll.do',data=data)
 for attempt in range(3):
  try:
   result=json.load(urllib.request.urlopen(req,timeout=30));path.write_text(json.dumps(result,ensure_ascii=False,indent=2));return result
  except Exception:
   if attempt==2: raise
   time.sleep(1)
first=page(1); count=first['paginationInfo']['totalPageCount']
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: results=list(pool.map(page,range(1,count+1)))
rows=[row for data in results for row in data['resultList']]
assert len(rows)==first['paginationInfo']['totalRecordCount']
assert len(set(r['schl_id'] for r in rows))==len(rows)
(out/'academy-2026.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
from collections import Counter
print('total',len(rows));print(Counter(r['schl_div_nm'] for r in rows));print(Counter(r['schl_knd_nm'] for r in rows));print('Sangmyung',[r for r in rows if '상명' in r['schl_nm']]);print('special',[r['schl_nm'] for r in rows if '사관' in r['schl_nm'] or '경찰' in r['schl_nm'] or '폴리텍' in r['schl_nm']])
