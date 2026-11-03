import json
from pathlib import Path
import time
import urllib.parse
import urllib.request
import html
import re

ROOT=Path(__file__).resolve().parent
BASE='https://www.hansung.ac.kr'
results=[]
for keyword in ['폐강','수강신청','강의시간표','수업시간','집중이수']:
    for page in [1,2]:
        url=BASE+'/bbs/hansung/2127/artclList.do?'+urllib.parse.urlencode({'findType':'sj','findWord':keyword,'page':page})
        with urllib.request.urlopen(urllib.request.Request(BASE+'/bbs/hansung/2127/artclList.do',urllib.parse.urlencode({'findType':'sj','findWord':keyword,'page':page}).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':BASE+'/bbs/hansung/2127/artclList.do'}),timeout=30)as f:raw=f.read()
        (ROOT/f'hansung-current-search-{keyword}-{page}.html').write_bytes(raw)
        text=raw.decode('utf-8');items=[]
        if not re.search(r'name="findWord"[^>]*value="'+re.escape(keyword)+r'"',text):raise ValueError('Public search did not apply requested title filter')
        for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',text,re.S):
            a=re.search(r'<a\b[^>]*href="([^"]*artclView\.do)"[^>]*>(.*?)</a>',row,re.S)
            date=re.search(r'<td class="td-date">([^<]+)</td>',row)
            if a is None or date is None:continue
            title=re.search(r'<strong>(.*?)</strong>',a[2],re.S)
            value=title[1] if title else a[2]
            items.append({'title':html.unescape(re.sub(r'<[^>]+>','',value)).strip(),'publishedDate':date[1].strip(),'url':urllib.parse.urljoin(BASE,a[1])})
        if not items:raise ValueError('Unrecognized actual board result rows')
        results.append({'keyword':keyword,'page':page,'url':url,'items':items})
        time.sleep(.4)
(ROOT/'hansung-current-central-change-search-audit.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
for r in results:
 for i in r['items']:
  if i['publishedDate']>='2026.08.01':print(r['keyword'],i['publishedDate'],i['title'],i['url'])
