from pathlib import Path
import requests,openpyxl,json,hashlib
p=Path(__file__).parent;out=[];sources=[]
for no,name in [(141734,'postopening-major.xlsx'),(141735,'postopening-general.xlsx')]:
 url=f'https://www.deu.ac.kr/www/gra-notice.do?mode=download&articleNo=348405&attachNo={no}';r=requests.get(url,timeout=25);f=p/name;f.write_bytes(r.content);sources.append({'url':url,'status':r.status_code,'path':str(f),'bytes':len(r.content),'sha256':hashlib.sha256(r.content).hexdigest()})
 if r.content.startswith(b'PK'):
  b=openpyxl.load_workbook(f,data_only=True)
  for sheet in b:
   print(name,sheet.title,sheet.max_row,sheet.max_column)
   for i,row in enumerate(sheet.values):
    cells=list(row)
    if i<4:print(cells)
    out.append({'file':name,'sheet':sheet.title,'row':i+1,'cells':cells})
(p/'postopening-native-rows.json').write_text(json.dumps(out,ensure_ascii=False,indent=2,default=str));(p/'postopening-sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2))
