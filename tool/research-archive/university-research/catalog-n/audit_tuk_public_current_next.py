# coding: utf-8
"""Research-only public board consistency audit; no login or fabricated identity."""
import json,re,time,urllib.request,urllib.parse
from html.parser import HTMLParser
from pathlib import Path
P=Path(__file__).resolve().parent
class Text(HTMLParser):
 def __init__(self):super().__init__();self.parts=[]
 def handle_data(self,d):self.parts.append(d)
def text(s):
 t=Text();t.feed(s);return ' '.join(' '.join(t.parts).split())
s=(P/'tuk-final-closure-search.html').read_text()
layout=re.search(r'name="layout" value="([^"]+)"',s)[1]
base='https://www.tukorea.ac.kr'
body=urllib.parse.urlencode({'layout':layout,'page':'1','findType':'sj','findWord':'2026학년도 2학기 폐강'}).encode()
def post(path):
 with urllib.request.urlopen(urllib.request.Request(base+path,data=body),timeout=35) as r:return r.status,r.read().decode('utf-8')
status,listing=post('/combBbs/haksa/1/list.do')
observed=list(dict.fromkeys(re.findall(r"jf_combBbs_view\('([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'",listing)))
assert ('haksa','1','107','153119') in observed
# Only the actually observed public view route is requested.
time.sleep(.7)
status,view=post('/combBbs/haksa/1/107/153119/view.do')
rows=[]
for tr in re.findall(r'<tr\b[^>]*>(.*?)</tr>',view,re.S):
 cells=[text(x) for x in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',tr,re.S)]
 if len(cells)==8 and re.fullmatch(r'[A-Z]{3}[A-Z0-9]{5,6}',cells[1]) and re.fullmatch(r'\d{2}',cells[2]):rows.append(cells)
old=json.loads((P/'tuk-final-closure-rows.json').read_text());oldkeys={(x[1],x[2]) for x in old};newkeys={(x[1],x[2]) for x in rows}
assert len(rows)==36 and len(newkeys)==36
assert not (P/'tuk-current-closure-crosscheck-next-20261008.json').exists()
out={'researchOnly':True,'captureDate':'2026-10-08','normalPublishedSearchUrl':base+'/combBbs/haksa/1/list.do','publishedFindType':'sj','publishedFindWord':'2026학년도 2학기 폐강','actualObservedViewUrl':base+'/combBbs/haksa/1/107/153119/view.do','status':status,'publishedNoticeDate':'2026-09-08','observedCurrentMatchingNoticeRoutes':['/'.join(x) for x in observed],'closureRows':rows,'priorClosureCount':len(oldkeys),'currentClosureCount':len(newkeys),'addedClosedKeys':sorted(newkeys-oldkeys),'removedClosedKeys':sorted(oldkeys-newkeys),'limitation':'Title-specific central notice search and actual36-row notice; not a current complete offering/clock/room publication.'}
(P/'tuk-current-closure-crosscheck-next-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print('current closure rows',len(rows),'added',len(newkeys-oldkeys),'removed',len(oldkeys-newkeys))
