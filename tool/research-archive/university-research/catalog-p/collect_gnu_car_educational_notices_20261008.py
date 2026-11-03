import urllib.request,re,html,json,time
from pathlib import Path
out=[]
for ident in ['7842826','8236122']:
 time.sleep(.8);u=f'https://www.gnu.ac.kr/car/na/ntt/selectNttInfo.do?bbsId=2131&mi=5865&nttSn={ident}'
 s=urllib.request.urlopen(u,timeout=30).read().decode()
 # Only the educational article, excluding headers/footer/contact fields.
 m=re.search(r'<div class="BD_table">(.*?)<div class="btn_st',s,re.S)
 if not m:
  print(ident,[(x,s[max(0,s.find(x)-70):s.find(x)+100]) for x in ['nttCn','bbs_view','bbsV','conTxt'] if x in s]);continue
 text=html.unescape(re.sub('<[^>]+>',' ',m[1]));text=re.sub(r'\s+',' ',text).strip()
 text=re.sub(r'(?:\+?82[- ]?)?0\d{1,2}[-) ]\d{3,4}[- ]\d{4}','[연락처 제외]',text)
 text=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[연락처 제외]',text)
 links=[{'url':html.unescape(a),'label':html.unescape(re.sub('<[^>]+>','',b))} for a,b in re.findall(r'<a[^>]+href="([^\"]+)"[^>]*>(.*?)</a>',s,re.S) if 'nttFileDownload' in a]
 out.append({'sourceUrl':u,'educationalArticle':text,'publishedAttachmentLinks':links});print(ident,text[:2200],links)
Path('work/university-research/catalog-p/gnu-car-current-educational-notices-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
