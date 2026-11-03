import concurrent.futures,json,urllib.request,urllib.parse,pathlib,re,html
out=pathlib.Path('work/university-directory')
def page(i):
 path=out/f'career{i}.html'
 if path.exists(): text=path.read_text()
 else:
  params=urllib.parse.urlencode(dict(pageIndex=i,mPageSize=30))
  text=urllib.request.urlopen('https://m.career.go.kr/cnet/web/base/school/schoolUniversityList.mdo?'+params,timeout=30).read().decode('utf-8')
  path.write_text(text)
 p=re.compile(r'<h3>\s*<a href="([^"]*)" target="_blank">(.*?)</a>[^<]*<span class="category">(.*?)</span>\s*</h3>\s*<div class="desc">\s*(.*?)</div>',re.S)
 result=[dict(link=html.unescape(a),name=html.unescape(b).strip(),region=html.unescape(c).strip(),kind=html.unescape(d).strip()) for a,b,c,d in p.findall(text)]
 return result
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: rows=[r for p in pool.map(page,range(1,17)) for r in p]
print('rows',len(rows)); assert len(rows)==472
(out/'career-all.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print('Non-disclosure categories:',[r for r in rows if '사내대학' in r['kind'] or '전공대학' in r['kind'] or '원격대학' in r['kind'] or '사관' in r['name'] or '경찰' in r['name']])
