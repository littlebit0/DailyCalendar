from pathlib import Path
from bs4 import BeautifulSoup as B
import requests
p=Path(__file__).parent;url='https://mce.konyang.ac.kr/cop/bbs/BBSMSTR_000000000559/selectBoardArticle.do?nttId=290803'
r=requests.get(url,timeout=30);(p/'konyang-nursing-notice.html').write_bytes(r.content);d=B(r.content,'html.parser')
for a in d.select('a'):
 if any(x in a.get_text() for x in ['시간표','xlsx','hwp','pdf']):print(a.get_text(' ',strip=True),a.get('href'),a.get('onclick'))
print(d.get_text(' ',strip=True)[-6500:])
