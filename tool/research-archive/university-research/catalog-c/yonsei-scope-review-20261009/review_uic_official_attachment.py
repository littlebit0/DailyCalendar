import io,json,hashlib,re,urllib.request
from pathlib import Path
from pypdf import PdfReader
p=Path(__file__).parent
url='https://uic.yonsei.ac.kr/downloadfile.php?cmid=m07_01_02&mid=m07_01_02&ucnt=1&uid=14453'
with urllib.request.urlopen(url,timeout=40) as r:
 data=r.read();status=r.status
assert data.startswith(b'%PDF')
reader=PdfReader(io.BytesIO(data))
terms=['parenthes','bracket','timetable','period','laboratory','practice','2026','18:50','19:00']
receipt={'researchOnly':True,'completionClaim':False,'sourceUrl':url,'httpStatus':status,'sourceSha256':hashlib.sha256(data).hexdigest(),'pages':len(reader.pages),'wholePdfSaved':False,'educationalKeywordPageInventory':[]}
for i,page in enumerate(reader.pages,1):
 t=page.extract_text() or ''
 hits=[w for w in terms if w in t.lower()]
 if hits:receipt['educationalKeywordPageInventory'].append({'page':i,'keywords':hits})
(p/'uic-current-official-guide-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Official UIC PDF pages',len(reader.pages),'SHA',receipt['sourceSha256'])
for x in receipt['educationalKeywordPageInventory']:print(x)

last=reader.pages[-1].extract_text() or ''
lines=[]
for line in last.splitlines():
 if re.search(r'@|(?:0(?:2|[3-6]\d))[-) ]\d{3,4}[- ]\d{4}|\b(?:contact|email|phone|fax)\b',line,re.I):continue
 lines.append(line)
(p/'uic-current-guide-page33-educational-text.json').write_text(json.dumps({'researchOnly':True,'sourceSha256':receipt['sourceSha256'],'physicalPage':33,'educationLines':lines,'wholePageSaved':False,'layoutVisuallyVerified':False},ensure_ascii=False,indent=2)+'\n')
print('EDUCATIONAL PAGE33:')
print('\n'.join(lines))
