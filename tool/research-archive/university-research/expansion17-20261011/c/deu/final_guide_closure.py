from pathlib import Path
from bs4 import BeautifulSoup as B
import requests,hashlib
from pypdf import PdfReader
p=Path(__file__).parent
url='https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=348405';r=requests.get(url,timeout=25);(p/'postopening-closure348405.html').write_bytes(r.content);d=B(r.content,'html.parser')
for a in d.select('a'):
 if 'mode=download' in a.get('href',''):print(a.get_text(' ',strip=True),a['href'])
text=d.get_text(' ',strip=True);i=text.find('2026학년도 2학기 개강 후');print(text[i:i+2600])
url='https://www.deu.ac.kr/www/gra-notice.do?mode=download&articleNo=80309&attachNo=123500';r=requests.get(url,timeout=25);f=p/'current2026-final-guide.pdf';f.write_bytes(r.content);print('guide',r.status_code,len(r.content),hashlib.sha256(r.content).hexdigest())
if r.content.startswith(b'%PDF'):
 reader=PdfReader(f);text='\n'.join(page.extract_text() for page in reader.pages);f.with_suffix('.txt').write_text(text);print('pages',len(reader.pages));print('\n'.join(x for x in text.splitlines() if any(y in x for y in ['교시','50분','수업시간','09:00','09:30','강의시간'])))
