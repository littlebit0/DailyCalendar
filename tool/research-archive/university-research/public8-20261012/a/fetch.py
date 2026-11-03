import requests,json,pathlib
from bs4 import BeautifulSoup
from urllib.parse import urljoin
P=pathlib.Path('work/university-research/public8-20261012/a')
def fetch(name,url):
 r=requests.get(url,timeout=35);r.encoding=r.apparent_encoding
 (P/(name+'.html')).write_text(r.text)
 s=BeautifulSoup(r.text,'html.parser');(P/(name+'.txt')).write_text(s.get_text('\n',strip=True))
 links=[{'text':a.get_text(' ',strip=True),'url':urljoin(r.url,a.get('href','')),'onclick':a.get('onclick','')}for a in s.select('a')]
 (P/(name+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2))
 print(name,r.status_code,r.url,len(r.content));return links
if __name__=='__main__':
 for n,u in [('sunmoon-dla','https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttList.do?bbsId=1256&mi=41117'),('kentech-home','https://www.kentech.ac.kr/')]:
  try:fetch(n,u)
  except Exception as e:print(n,str(e))
