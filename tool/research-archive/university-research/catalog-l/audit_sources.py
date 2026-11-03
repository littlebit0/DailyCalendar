import pathlib,json,re,urllib.request,html
from html.parser import HTMLParser
P=pathlib.Path(__file__).parent
class Table(HTMLParser):
 def __init__(self):super().__init__();self.tables=[];self.rows=None;self.row=None;self.cell=None
 def handle_starttag(self,t,a):
  if t=='table':self.rows=[]
  if t=='tr' and self.rows is not None:self.row=[]
  if t in ('td','th') and self.row is not None:self.cell=[]
 def handle_data(self,d):
  if self.cell is not None:self.cell.append(d)
 def handle_endtag(self,t):
  if t in ('td','th') and self.cell is not None:self.row.append(' '.join(''.join(self.cell).split()));self.cell=None
  if t=='tr' and self.row is not None:self.rows.append(self.row);self.row=None
  if t=='table' and self.rows is not None:self.tables.append(self.rows);self.rows=None
h=Table();h.feed((P/'syu-2026-2-final-closure.html').read_text())
(P/'syu-2026-2-closure-tables.json').write_text(json.dumps(h.tables,ensure_ascii=False,indent=2))
r=json.loads((P/'syu-2026-2-public-all-rows.json').read_text())
print('SYU rows schema',type(r).__name__,len(r));print('closuretables',h.tables)
from openpyxl import load_workbook
for f in P.glob('skuniv*closure.xlsx'):
 w=load_workbook(f,data_only=True);d={s.title:list(s.values) for s in w}
 (P/(f.stem+'.json')).write_text(json.dumps(d,ensure_ascii=False,indent=2,default=str));print(f.name,d)
u='https://www.syu.ac.kr/wp-admin/admin-ajax.php?action=file_download_id&t_id=252023&o_name=2026%ED%95%99%EB%85%84%EB%8F%84-2%ED%95%99%EA%B8%B0-%EC%88%98%EA%B0%95%EC%8B%A0%EC%B2%AD-%EC%95%88%EB%82%B4%EB%AC%B8-1.pdf'
b=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read();(P/'syu-2026-2-registration-guide.pdf').write_bytes(b)
import pdfplumber
with pdfplumber.open(P/'syu-2026-2-registration-guide.pdf') as pdf:
 text='\n'.join(p.extract_text() or '' for p in pdf.pages)
(P/'syu-2026-2-registration-guide.txt').write_text(text)
print('SYU guide',len(b),len(text));print(text[:1300])
