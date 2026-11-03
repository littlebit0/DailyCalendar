import urllib.request, json, hashlib, re
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
root=Path('work/university-research/resume-20261011')
urls={'snue':'https://www.snue.ac.kr/snue/na/ntt/selectNttList.do?bbsId=1081&mi=1280','cnue':'https://www.cnue.ac.kr/cnue/news/notice02.do'}
def one(item):
 school,url=item
 try:
  r=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=25); raw=r.read(); text=raw.decode('utf-8','replace')
  # Public notice education titles only. Do not preserve notices containing pupil allocations.
  education=[]
  for row in re.findall(r'<tr\b[^>]*>.*?</tr>',text,re.S|re.I):
   plain=re.sub('<[^>]+>',' ',row); plain=re.sub(r'\s+',' ',plain).strip()
   if any(w in plain for w in ['수강','강의','시간표','학기','학사']):
    names=[]
    for a,title in re.findall(r'<a\b([^>]*)>(.*?)</a>',row,re.S|re.I):
     title=re.sub('<[^>]+>',' ',title); title=re.sub(r'\s+',' ',title).strip()
     if title and any(w in title for w in ['수강','강의','시간표','학기','학사']):
      href=re.search(r'href=[\"\']([^\"\']+)',a); names.append({'title':title,'href':href.group(1) if href else None})
    if names: education+=names
  receipt={'sourceUrl':url,'status':r.status,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'educationNoticeLinks':education,'sourceOnly':True,'completionClaim':False}
 except Exception as e: receipt={'sourceUrl':url,'error':str(e),'sourceOnly':True,'completionClaim':False}
 (root/school/'current-list-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
 return school,receipt
for s,r in ThreadPoolExecutor(2).map(one,urls.items()): print(s,json.dumps(r,ensure_ascii=False)[:1000])
