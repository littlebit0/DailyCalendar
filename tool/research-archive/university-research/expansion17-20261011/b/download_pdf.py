import requests,pathlib,json
from pypdf import PdfReader
P=pathlib.Path(__file__).parent
U={'sungkyul-spring-guide':'https://www.sungkyul.ac.kr/bbs/skukr/96/25840/download.do','sungkyul-spring-timetable':'https://www.sungkyul.ac.kr/bbs/skukr/96/26021/download.do'}
for n,u in U.items():
 r=requests.get(u,timeout=35);(P/(n+'.pdf')).write_bytes(r.content)
 try:
  pages=PdfReader(P/(n+'.pdf')).pages;(P/(n+'.txt')).write_text('\n'.join(x.extract_text(extraction_mode='layout') for x in pages));print(n,len(pages))
 except Exception as e:print(n,r.status_code,str(e))
