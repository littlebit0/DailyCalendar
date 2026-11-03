"""Preserve actual curriculum-specific DGIST data; no activation/clock inference."""
import json,re,collections
from pathlib import Path
P=Path(__file__).resolve().parent
u={}
for y in ['2020','2024','2014']:
 for r in json.loads((P/f'dgist2026-2-{y}-curriculum-rows.json').read_text()):
  u.setdefault((r['SBJT_NO'],r['CLSS_NO']),[]).append((y,r))
result=[]
clock=re.compile(r'([월화수목금토일])(\d\d):(\d\d)-(\d\d):(\d\d)\(([^()]*)\)')
for key,variants in u.items():
 r=variants[0][1];raw=r.get('TLSN_TIME','');matches=list(clock.finditer(raw));residue=clock.sub('',raw).replace(',','').strip();slots=[]
 for m in matches:
  day,h,mi,eh,em,room=m.groups();start=int(h)*60+int(mi);end=int(eh)*60+int(em)
  assert 0<=start<end<=1440
  slots.append(dict(weekday='월화수목금토일'.index(day)+1,startMinute=start,endMinute=end,room=room))
 research=r['SBJT_NO'].startswith(('RP','INT'))
 result.append(dict(courseCode=key[0],section=key[1],curriculumVariants=[dict(curriculumYear=y,title=x['SBJT_NM'],category=x['CPTN_NM'],credit=x['PNT'],department=x['ASGN_SUST_NM'],remarks=x.get('REMK','')) for y,x in variants],rawTime=raw,syntaxParsedSlots=slots,unparsedResidue=residue,planPublished=int(r.get('LECPLN_CNT',0))>0,operatingReviewRequired=research,recurrenceVerified=False,activationReady=False))
assert len(result)==569 and all(not x['unparsedResidue'] for x in result)
(P/'dgist2026-2-normalized-research.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
a=dict(sourceUrl='https://welcome.dgist.ac.kr/ucs/ucsqProfRespSbjtInq/index.do',unionCount=len(result),curriculumRowCounts={'2020':551,'2024':192,'2014':542},syntaxParsed=569,clockConflicts=sum(len({x['TLSN_TIME'] for _,x in v})>1 for v in u.values()),titleVariants=sum(len({x['SBJT_NM'] for _,x in v})>1 for v in u.values()),researchOrInternship=sum(x['operatingReviewRequired'] for x in result),plansUnpublished=sum(not x['planPublished'] for x in result),publicAIUniversityRows=0,termEvidence={'start':'2026-08-24','end':'2026-12-11','source':'DGIST-authored 2026-2 exchange guide; Korea University official distribution'},cancellationVerified=False,completionClaim=False)
(P/'dgist2026-2-field-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(a,ensure_ascii=False))
