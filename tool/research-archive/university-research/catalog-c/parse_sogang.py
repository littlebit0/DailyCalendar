from pathlib import Path
import re,html,json
ROOT=Path(__file__).parent
s=(ROOT/'sogang-search.xml').read_text()
headers=['year','semester','division','department','subjectCode','section','title','syllabus','credit','meetingText','hours','professor','enrollment','english','chinese','approval','CU','HUSS','CI','oddEven','international','honors','cyber','exam','target','recommendedGrade','registrationRemarks','description','remarks']
records=[]
for rawrow in re.findall(r'<tr\b[^>]*>(.*?)</tr>',s,re.S):
 cells=re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>',rawrow,re.S)
 values=[html.unescape(re.sub('<[^>]+>',' ',x)).replace('\xa0',' ').strip()for x in cells]
 if len(values)==29 and re.fullmatch(r'[A-Z]+\d+',values[4]):records.append(dict(zip(headers,values)))
assert len(records)==1541,len(records)
assert len({(r['subjectCode'],r['section'])for r in records})==1541
(ROOT/'sogang-2026-2.json').write_text(json.dumps({'officialReportedRows':1541,'actualRows':len(records),'records':records},ensure_ascii=False,indent=2)+'\n')
print('1541 unique courses/sections','untimed',sum(not r['meetingText']for r in records),'sample',records[0])
