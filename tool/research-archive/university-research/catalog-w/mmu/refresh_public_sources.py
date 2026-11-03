"""Read observed public MMU sources sequentially; retain education and receipts only."""
import hashlib,io,json,time,urllib.request
from pathlib import Path
from lxml import html
import openpyxl
R=Path(__file__).parent
BASE='https://www.mmu.ac.kr'
receipts=[]
def get(path):
 url=BASE+path
 with urllib.request.urlopen(url,timeout=30) as res:
  assert res.status==200;body=res.read(8_000_001)
  assert len(body)<=8_000_000
 receipts.append({'url':url,'sha256':hashlib.sha256(body).hexdigest(),'bytes':len(body)})
 time.sleep(.35)
 return body
# Actual latest observed changed-grid link, its parent and source clock.
for path,key in [('/main/board/302/1/read/89163','change'),('/main/contents/lesson','clock'),('/main/board/302/1/read/89128','closure')]:
 doc=html.fromstring(get(path)); text=' '.join(doc.text_content().split())
 if key=='change':
  assert '2026학년도 제2학기 수업시간표 변경 안내' in text
  assert '/main/board/302/1/download/89163/59805' in doc.xpath('//a/@href')
 if key=='clock':
  target=next(x for x in doc.xpath('//p') if '50분' in x.text_content())
  table=next(x for x in doc.xpath('//table') if '13교시' in x.text_content())
  (R/'current-clock-education.json').write_text(json.dumps({'url':BASE+path,'rule':' '.join(target.text_content().split()),'rows':[[' '.join(c.text_content().split()) for c in row.xpath('./th|./td')] for row in table.xpath('.//tr')]},ensure_ascii=False,indent=2)+'\n')
 if key=='closure':
  i=text.index('2026학년도 제2학기 폐강 대상 교과목 알림')
  fragment=text[i:text.index('목록 대학/대학원',i)]
  (R/'closure-status-education.json').write_text(json.dumps({'url':BASE+path,'text':fragment,'finalClosureConfirmed':False},ensure_ascii=False,indent=2)+'\n')
body=get('/main/board/302/1/download/89163/59805')
old=Path('work/university-research/catalog-j/mmu-2026-2-current.xlsx').read_bytes()
assert hashlib.sha256(body).digest()==hashlib.sha256(old).digest(), 'Grid changed; review new source first'
w=openpyxl.load_workbook(io.BytesIO(body),data_only=True);s=w['자료']
header=[c.value for c in s[2]];out=[]
for r in range(3,251,2):
 first=[c.value for c in s[r]];second=[c.value for c in s[r+1]]
 assert first[:4]==second[:4]
 slots=[]
 for col in range(5,len(header)):
  title=first[col]
  if not title or not str(title).strip():continue
  raw=str(second[col] or '').strip();bits=raw.split(maxsplit=1)
  slots.append({'sourceColumn':col+1,'period':header[col],'courseName':str(title).strip(),'sourceRoomProfessor':raw,'room':bits[0] if bits else '', 'professor':bits[1] if len(bits)==2 else ''})
 out.append({'sourceRow':r,'year':first[0],'semester':first[1],'department':first[2],'yearLevel':first[3],'classGroup':first[4],'slots':slots})
(R/'current-grid-education.json').write_text(json.dumps({'url':BASE+'/main/board/302/1/download/89163/59805','title':s.cell(1,1).value,'rows':out},ensure_ascii=False,indent=2)+'\n')
calendar=json.loads(get('/main/scheduleList?libType=D&searchDt=&hakgi=0&recordCnt=999&year=2026'))
(R/'current-calendar-education.json').write_text(json.dumps({'url':receipts[-1]['url'],'rows':[{k:x[k] for k in ['title','frdt','todt']} for x in calendar['list']]},ensure_ascii=False,indent=2)+'\n')
(R/'current-source-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
print('grid unchanged; educational pairs',len(out),'slots',sum(len(x['slots']) for x in out))
body=get('/main/board/302/1/download/89128/59637')
wb=openpyxl.load_workbook(io.BytesIO(body),data_only=True);sheet=wb.active
assert sheet.cell(1,1).value=='2026학년도 제2학기 폐강 대상 교과목 목록'
fields={0:'year',1:'semester',2:'termKind',3:'department',4:'yearLevel',5:'classGroup',6:'courseCode',7:'courseName',8:'classification',9:'credits',10:'theory',11:'practice',14:'professor'}
rows=[]
for r in list(sheet.values)[2:]:
 if r[6]: rows.append({name:r[i] for i,name in fields.items()})
(R/'closure-candidate-education.json').write_text(json.dumps({'url':receipts[-1]['url'],'finalClosureConfirmed':False,'rows':rows},ensure_ascii=False,indent=2)+'\n')
(R/'current-source-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
print('public closure candidate educational rows',len(rows))
