"""Extract only published educational lecture cells, with original document locators."""
import json,re,runpy,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).parent
source=Path('/private/tmp/kongju-current-whole-1.hwp')
sys.argv=['hwp',str(source)]
data=runpy.run_path(str(ROOT.parents[2]/'catalog-l/hwp_tables_research.py'))
tables=data['tables'];clean=data['text_clean'];contexts={};paras=[];index=-1
for tag,level,payload in data['records']:
 if tag==77:
  index+=1
  contexts[index]=paras[-14:]
 if tag==67:
  text=clean(payload)
  if text:paras.append(text)
def sanitize(text):
 text=re.sub(r'(?:☎|☏|전화|TEL|문의[:：]?)\s*[\d\s()\-]+','',text)
 text=re.sub(r'0\d{1,2}[-)]\d{3,4}[-]\d{4}','',text)
 return re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','',text).strip()
academic=[]
for t in tables:
 if t['index']<215:continue
 cells=[]
 for c in t['cells']:
  cell={k:c[k] for k in ['row','col','colSpan','rowSpan']};cell['text']=sanitize('\n'.join(c['paragraphs']));cells.append(cell)
 academic.append({'sourceTable':t['index'],'precedingEducationalContext':[sanitize(x) for x in contexts[t['index']] if '@' not in sanitize(x)],'cells':cells})
clock=[]
for i in [212,213,214]:
 t=tables[i];clock.append({'sourceTable':i,'precedingEducationalContext':[sanitize(x) for x in contexts[i]],'cells':[{k:c[k] for k in ['row','col','colSpan','rowSpan']}|{'text':sanitize('\n'.join(c['paragraphs']))} for c in t['cells']]})
result={'title':'2026학년도2학기 강의일람표 본책 배포용20260731','sourceHwpSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'sourceZIPURL':'https://www.kongju.ac.kr/bbs/KNU/2128/655398/download.do','publicationScope':'Current2026-2institution undergraduate general education/teaching/major lecture tables, actual9digit printed 과목번호 retained without inventing separate section. Book2 curriculum inventories are excluded from current actual offering extraction.','educationalTables':academic,'clockAndCampusTables':clock}
(ROOT/'current-whole-undergraduate-lecture-education.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('educational lecture tables',len(academic),'clock/campus3')
