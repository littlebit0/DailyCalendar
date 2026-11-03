"""Audit whole HUFS public source and acquired educational plan contexts."""
import json,re
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PATTERNS={
 'remote':r'이러닝|(?i:\be[ -]?learning\b)|[Ff]lipped|비대면|실시간|온라인|녹화|동영상|사이버|원격|[Ww]ebex|[Zz]oom|[Pp]anopto|[Aa]synchron|[Ss]ynchronous|\b[Oo]n[- ]?line\b|[Rr]eal[- ]time',
 'exceptions':r'休講|補講|수업\s*(?:없|X\b|x\b|안)|수업.{0,12}(?:하지\s*않|없습니다|없음)|강의.{0,12}없|(?i:no\s+(?:lecture|teaching)|reading\s+week|class\s+(?:suspend|not\s+held))|교외|답사|견학|대체.?출석|출석.?대체|체험.?학습|현장.?방문|(?i:field[ -]?(?:work|trip|visit)|excursion|off[ -]?campus|site[ -]?visit|museum[ -]?visit)|추석|한글날|개천절|공휴|대체.?휴|휴교|(?i:holiday|Chuseok|Hange?ul)|휴강|보강|휴업|대체.?강의|대체.?수업|수업.?시간.{0,8}변경|시간.{0,8}추후|협의|집중.?수업|집중.?강의|현장.?실습|현장.?학습|[Mm]ake[- ]?up|[Cc]ancel(?:led|ed)|[Nn]o class|[Ff]ield.?[Tt]rip',
 'dated':r'(?<!\d)(?:0?[1-9]|1[0-2])[/.](?:0?[1-9]|[12]\d|3[01])(?!\d)|(?i:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?\s+\d{1,2}|\d{1,2}\s*월\s*\d{1,2}\s*일|2026[./-]\d{1,2}[./-]\d{1,2}|\d{1,2}:\d{2}',
 'weekday':r'(?i:\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Tues|Wed|Thu|Thurs|Fri|Sat|Sun)\b)|(?:매주|매|오직|만|요일에|예외).{0,8}[월화수목금토일]요일',
}
def matches(text):
 tags=[name for name,pattern in PATTERNS.items() if re.search(pattern,text)]
 if 'dated' in tags:
  hits=re.findall(PATTERNS['dated'],text)
  if hits and all(hit in {'1/4','1/3','2/3'} for hit in hits) and re.search(r'결석|출석|학칙|ausencia|asistencia|attendance|absen|出席|欠席',text,re.I):
   tags.remove('dated')
 return tags
rows=json.loads((ROOT/'hufs-current-20261008/courses.json').read_text())
unique={(r['queryCampus'],r['row']['lssnCd']):r['row'] for r in rows}
raw=[];plans=[];missing=[]
for (campus,key),row in sorted(unique.items()):
 notes='\n'.join(row.get(k) or '' for k in ['etc','etc2','etc3','etc4'])
 tags=matches(notes)
 if tags:raw.append({'campus':campus,'key':key,'tags':tags,'sourceSchedule':row.get('dayTimeDisplay'),'notes':notes})
 path=ROOT/'hufs-public-operating-plans'/f'{campus}-{key}.json'
 if not path.exists():missing.append(campus+'/'+key);continue
 doc=json.loads(path.read_text());fields=doc['fields'];contexts={}
 for name,value in fields.items():
  if name in ['methods','notes','delivery'] and matches(value):contexts[name]={'tags':matches(value),'text':value}
 for week,value in fields.get('weekly',{}).items():
  if matches(value):contexts[week]={'tags':matches(value),'text':value}
 if contexts:plans.append({'campus':campus,'key':key,'sourceUrl':doc['sourceUrl'],'contexts':contexts})
result={'researchOnly':True,'completionClaim':False,'courseCount':len(unique),'wholeSourceRemarksReviewed':True,'plansAcquired':len(unique)-len(missing),'wholePlansAcquired':not missing,'semanticReviewComplete':False,'rawFlagCount':len(raw),'planFlagCount':len(plans),'rawContexts':raw,'planContexts':plans,'missingPlans':missing}
(ROOT/'hufs-whole-operating-contexts.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print({k:result[k] for k in ['courseCount','plansAcquired','wholePlansAcquired','rawFlagCount','planFlagCount','semanticReviewComplete']})
