"""Audit actual published tables; no inferred identity, clock, or active registration."""
import json,re
from pathlib import Path
from collections import defaultdict
ROOT=Path(__file__).parent
normal=lambda v:re.sub(r'\s+','',v or '')
records=[]; audits=[]
for source in sorted(ROOT.glob('2026_2_*.tables.json')):
    if source.stem.startswith('2026_2_juyo'): continue
    tables=json.loads(source.read_text());found=[]
    for table in tables:
        rows=table['rows']; header=None
        for i,row in enumerate(rows[:4]):
            for col,cell in enumerate(row):
                if normal(cell)=='과목코드': header=(i,col,row);break
            if header:break
        if not header:continue
        start,ci,labels=header
        for ri,row in enumerate(rows[start+1:],start+1):
            code=normal(row[ci]) if ci<len(row) else ''
            if not re.fullmatch(r'\d{7}',code):continue
            record={'publishedCombinedCode':code,'source':source.name,'page':table['page'],'table':table['table'],'row':ri,'headers':labels,'values':row}
            found.append(record);records.append(record)
    unique=set(x['publishedCombinedCode'] for x in found)
    text_codes=set(re.findall(r'(?<!\d)\d{7}(?!\d)',source.with_name(source.name.replace('.tables.json','.txt')).read_text()))
    audits.append({'source':source.name,'actualRows':len(found),'uniqueCombinedCodes':len(unique),'textOnlyCodes':sorted(text_codes-unique),'tableOnlyCodes':sorted(unique-text_codes)})
by=defaultdict(list)
for r in records:by[r['publishedCombinedCode']].append(r)
summary={'productionReady':False,'completionClaim':False,'rawRows':len(records),'uniqueCombinedCodes':len(by),'repeatedCodes':sum(len(v)>1 for v in by.values()),'sources':audits,'missingFields':['current undergraduate clock','explicit 5+2 code boundary','latest classroom changes omitted by official changelog','special course actual periods','current closed/change application'],'prohibitedInference':'Combined official code retained whole; no guessed sections, clock, or repeated exceptional dates.'}
(ROOT/'bu-all-published-code-rows.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
(ROOT/'bu-all-published-table-audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2))
