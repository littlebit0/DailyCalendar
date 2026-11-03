"""Lossless public education rows grouped by official class ID; not activation."""
import ast,json,re,sys,hashlib
from pathlib import Path
from collections import Counter
p=Path(__file__).parent
sys.path.insert(0,str(p.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
module=ast.parse((p/'collect_hanyang_current_education.py').read_text())
allowed=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='allowed' for t in n.targets))
restrict_keys={'suupNo','suupYear','suupTerm','isujehanSosokNm','isujehanJeongongGb','isujehanJeongongNm','grade1','grade2','grade3','grade4','grade5','bigo','preTermApplyYn','aftTermApplyYn','isujehanGb','isujehanNm'}
restrictions=json.loads((p/'hanyang-2026-2-restrictions-all.json').read_text())
mask_audit=[]
def safe(row,fields,course):
 result={}
 for k,v in row.items():
  if k not in fields:continue
  if isinstance(v,str):
   v,masked,lost=filter_education(v)
   if masked or lost:mask_audit.append({'course':course,'field':k,'masked':masked,'lostLines':lost})
  result[k]=v
 return result
allcourses=[];stats={}
clock=re.compile(r'([월화수목금토일])\((\d\d:\d\d)-(\d\d:\d\d)\)')
for g in ['seoul','seoul-medicine','erica']:
 source=json.loads((p/f'hanyang-2026-2-{g}-all.json').read_text());groups={}
 for r in source['records']:
  key=r['suupNo'];groups.setdefault(key,[]).append(safe(r,allowed,key))
 counts=Counter()
 for key,aliases in groups.items():
  r=aliases[0];text=r['suupTimes'] or '';slots=clock.findall(text);complete=bool(slots) and not clock.sub('',text).replace(',','').strip()
  bounds=[]
  if r['jipjungGanguiYn']=='1':bounds.append('intensiveActualCourseDatesMissing')
  if not complete:bounds.append('publicClockMissingOrNonWeekly')
  if re.search('SMART-[FB]',r.get('teuksuNm') or ''):bounds.append('hybridOfflineAllocationRequiresEvidence')
  if re.search('E-러닝|온라인|원격',r.get('teuksuNm') or ''):bounds.append('remoteLiveVersusRecordedRequiresEvidence')
  room=r.get('suupRoomNms') or ''
  if not room or re.search('비지정|미지정',room):bounds.append('physicalRoomUnspecifiedSourcePreserved')
  if slots and len(room.split(','))!=len(slots):bounds.append('clockRoomPairingRequiresDetail')
  restriction_rows=[safe(z,restrict_keys,key) for ds in restrictions.get(key,{}).get('datasets',{}).values() for z in ds]
  if str(r['isuJehanYn'] or '').startswith('O') and not restriction_rows:bounds.append('restrictionMissing')
  record={'classId':key,'campus':g,'officialAliases':aliases,'restrictions':restriction_rows,'publicClockParts':[{'weekday':a,'start':b,'end':c} for a,b,c in slots],'operatingGaps':bounds,'current20261008CensusUnverified':True,'displayedAffiliationClassIsNotLectureSection':True}
  allcourses.append(record);counts.update(bounds);counts['unique']+=1;counts['aliases']+=len(aliases)
 stats[g]=dict(counts)
out={'researchOnly':True,'completionClaim':False,'freshCensusAcquired':False,'source':'https://portal.hanyang.ac.kr/sugang/SgscAct/findSuupSearchSugangSiganpyo.do','semester':'2026-2','courses':allcourses}
assert len(allcourses)==4961
file=p/'hanyang-cached-educational-scope-20261008.json';file.write_text(json.dumps(out,ensure_ascii=False,indent=2))
audit={'researchOnly':True,'completionClaim':False,'sourceScope':4961,'sourceDisplayedRows':sum(v['aliases'] for v in stats.values()),'restrictionRows':sum(len(z['restrictions']) for z in allcourses),'campuses':stats,'privacyRemovalAudit':mask_audit,'educationalSourcePath':str(file.resolve()),'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'currentAccessBoundary':'Normal anonymous entry now loads NetFunnel agent; no catalog POST attempted after detection. Hidden browser unavailable; no new visible tab.','pending':['freshCurrentCensus','publishedHolidayRule','courseClockRoomPairing','22IntensiveActualDateRanges','hybridOrRemoteDeliveryAllocation'],'sectionBoundary':'bunbanNo is00 for all rows, banNo varies across affiliation aliases. Preserve both raw; no made-up lecture section.'}
(p/'hanyang-educational-scope-gap-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print({k:v for k,v in audit.items() if k not in ['privacyRemovalAudit','campuses']});print(stats)
