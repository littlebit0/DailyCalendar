from lxml import html
from pathlib import Path
import json,re,collections,hashlib
p=Path(__file__).parent; f=p/'navi-query-all.html'; s=html.parse(str(f)); rows=[]
for i,tr in enumerate(s.xpath('//table/tbody/tr')):
 d={'sourceRow':i+1,'sourceUrl':'https://navi.inje.ac.kr/AllUsers/Lecture.aspx','year':2026,'semester':'second','level':'undergraduate'}
 for td in tr.xpath('./td[@title]'):d[td.get('title')]=' '.join(td.text_content().split())
 n=tr.xpath('.//input[@onclick]');d['reportOnclick']=n[0].get('onclick') if n else None
 opts=tr.xpath('.//select/option[@selected]') or tr.xpath('.//select/option');d['reportCAP']=opts[0].get('value') if opts else None
 rows.append(d)
keys=collections.Counter((d.get('교과목'),d.get('분반')) for d in rows)
receipt={'final':False,'wholeCompletion':False,'publishedCount':1838,'extractedRows':len(rows),'uniqueCodeSection':len(keys),'duplicateKeys':[{'code':k[0],'section':k[1],'rows':v} for k,v in keys.items() if v>1],'sourceSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'timingStatus':'list does not print time/room; actual linked reports being investigated','queryEvidence':'Official main registration page hyperlinks AllUsers/Lecture.aspx; default 01_2026_2 undergraduate; original visible 조회 button postback submitted without login.'}
(p/'inje-native-all-public-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));(p/'inje-native-all-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2));print(receipt)
