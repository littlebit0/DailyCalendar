import pathlib,json,sys,re,urllib.parse,urllib.request,time
sys.path.insert(0,'work/college-major-filters-20261012');from html_tree_c import Tree
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources');receipts={r['id']:r for r in json.load(open(p/'receipts.json'))};results=[];seen=set()
for file in p.glob('eulji-*-timetable-*.html'):
 root=Tree(file.read_text(errors='replace')).root
 for form in root.nodes('form'):
  fields={i.a.get('name'):i.a.get('value','')for i in form.nodes('input')if i.a.get('name')}
  for a in form.nodes('a'):
   match=re.search(r"submitForm\(this,'down',(\d+)",a.a.get('onclick',''))
   if not match or not re.search(r'2026.*(?:1|2)' ,a.txt()):continue
   n=match[1]
   if n in seen:continue
   seen.add(n);url=urllib.parse.urljoin(receipts[file.stem]['url'],'/skin/board/Valid.html')
   data={**fields,'act':'down','fno':n};req=urllib.request.Request(url,data=urllib.parse.urlencode(data).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':receipts[file.stem]['url']})
   r={'id':n,'title':a.txt(),'noticeUrl':receipts[file.stem]['url'],'requestUrl':url,'sourceNoticeFile':str(file),'method':'Normal official download form POST with existing visible hidden values; no login'}
   try:
    b=urllib.request.urlopen(req,timeout=25).read();ext='.pdf'if b[:4]==b'%PDF'else'.xlsx'if b[:2]==b'PK'else'.bin';target=p/('eulji-attachment-'+n+ext);target.write_bytes(b);r.update(file=str(target),bytes=len(b),magic=b[:8].hex());print(n,ext,len(b))
   except Exception as e:r['error']=str(e)
   results.append(r);time.sleep(.25)
(p/'eulji-attachment-receipts.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
