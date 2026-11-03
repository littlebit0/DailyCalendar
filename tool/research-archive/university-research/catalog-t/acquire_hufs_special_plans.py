"""Read current public special-course plans; keep educational fields only."""
from html.parser import HTMLParser
import json,re,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PRIOR=ROOT.parent/'catalogs'
class Cells(HTMLParser):
 def __init__(self):super().__init__();self.depth=0;self.buf='';self.values=[]
 def handle_starttag(self,tag,attrs):
  if tag in ['td','th']:self.depth+=1;self.buf=''
  if tag=='br' and self.depth:self.buf+='\n'
 def handle_data(self,text):
  if self.depth:self.buf+=text
 def handle_endtag(self,tag):
  if tag in ['td','th'] and self.depth:
   self.depth-=1;self.values.append(re.sub(r'[ \t\r]+',' ',self.buf).strip())
def educational_cells(cells):
 fields={}; labels={'학수번호':'identity','교과목명':'title','이수구분':'classification','학과 (Department)':'department','학점/강의시간':'creditsHours','강의시간(강의실위치)':'schedule','강의유형':'delivery','수업운영방식':'methods','기타안내 및 유의사항':'notes'}
 for i,value in enumerate(cells):
  if i+1<len(cells):
   for label,key in labels.items():
    if value.startswith(label):fields[key]=cells[i+1]
 weeks={}
 for i,value in enumerate(cells):
  if re.fullmatch(r'(?:[1-9]|1[0-6])(?:st|nd|rd|th)',value) and i+1<len(cells):weeks[value]=cells[i+1]
 fields['weekly']=weeks
 # Contact details are outside the allowlist and not kept even if embedded in a note.
 for key,value in list(fields.items()):
  if isinstance(value,str):fields[key]='\n'.join(line for line in value.splitlines() if not re.search(r'@|(?:010|02|0[3-6]\d)[ -]\d{3,4}[ -]\d{4}',line))
 return fields
entries=json.loads((PRIOR/'hufs-current-cyber-plan-contexts.json').read_text())['courses']; late=json.loads((PRIOR/'hufs-current-late-course-plan-clock-audit.json').read_text())['courses']
for c in late:entries.append({'campus':'H1','courseCodeSection':c['courseCodeSection'],'sourceUrl':c['sourceUrl']})
for campus,key in [('H2','M01401101'),('H1','N07360401'),('H2','O13314201'),('H1','Q05001101')]:
 entries.append({'campus':campus,'courseCodeSection':key,'sourceUrl':'https://wis.hufs.ac.kr/src08/jsp/lecture/syllabus.jsp?mode=print&ledg_year=2026&ledg_sessn=3&org_sect=A&lssn_cd='+key})
results=[]
for c in entries:
 with urllib.request.urlopen(urllib.request.Request(c['sourceUrl'],headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:body=response.read().decode('utf-8')
 parser=Cells();parser.feed(body);fields=educational_cells(parser.values)
 if not re.search(r'(?:^|\s)'+re.escape(c['courseCodeSection'])+r'$',fields.get('identity','')) or '2026-2학기' not in body:raise ValueError('Public course identity mismatch')
 results.append({'campus':c['campus'],'key':c['courseCodeSection'],'sourceUrl':c['sourceUrl'],'checkedDate':'2026-10-08','fields':fields})
 time.sleep(.4)
(ROOT/'hufs-current-special-plans-educational.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'courses':results},ensure_ascii=False,indent=2));print('current plans',len(results))
