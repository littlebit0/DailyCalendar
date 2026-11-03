import re,sys,json,html,hashlib,collections
src,out=sys.argv[1],sys.argv[2]
raw=open(src,'rb').read();t=raw.decode('utf-8')
body=t[t.find('<tbody'):] if '<tbody' in t else t
trs=re.findall(r'<tr\b.*?</tr>',body,re.S)
rows=[]
for i,tr in enumerate(trs):
  if '<th' in tr: continue
  d={'sourceRow':len(rows)+1,'sourceUrl':'https://navi.inje.ac.kr/AllUsers/Lecture.aspx','year':2026,'semester':'second','level':'undergraduate'}
  for k,v in re.findall(r'<td[^>]*\btitle="([^"]+)"[^>]*>(.*?)</td>',tr,re.S):
    d[html.unescape(k)]=' '.join(html.unescape(re.sub('<[^>]+>',' ',v)).split())
  m=re.search(r'onclick="(return PopupReportP\([^"]*)"',tr)
  d['reportOnclick']=html.unescape(m.group(1)) if m else None
  opts=re.findall(r'<option\b([^>]*)>',tr)
  sel=[o for o in opts if 'selected' in o] or opts
  mv=re.search(r'value="([^"]*)"',sel[0]) if sel else None
  d['reportCAP']=mv.group(1) if mv else None
  rows.append(d)
keys=collections.Counter((d.get('교과목'),d.get('분반')) for d in rows)
json.dump(rows,open(out,'w'),ensure_ascii=False,indent=1)
print(json.dumps({'rows':len(rows),'keys':len(keys),'withReport':sum(1 for r in rows if r['reportOnclick']),'keysWithReport':len({(r['교과목'],r['분반']) for r in rows if r['reportOnclick']}),'sha256':hashlib.sha256(raw).hexdigest()},ensure_ascii=False))
