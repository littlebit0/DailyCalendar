"""Verify complete Korean public selector acquisition against English source."""
from pathlib import Path
from collections import Counter,defaultdict
import json,re
P=Path(__file__).parent
major=json.loads((P/'skku-ko-major-all-2026-2.json').read_text());general=json.loads((P/'skku-ko-general-all-2026-2.json').read_text())
assert len(major['index'])==411
assert len(general['index'])==42
records=major['records']+general['records'];groups=defaultdict(list)
for r in records:groups[r['HAKSU_NO_BUNBAN']].append(r)
fields=['CAMPUS_GB','GYOSI_NAME','GWAMOK_NAME','BIGO','HAKJUM','PER_NAME','HAKBU_JIBJUNG_GB']
conflicts={k:{f:sorted({r.get(f,'')for r in v})for f in fields if len({r.get(f,'')for r in v})>1}for k,v in groups.items()};conflicts={k:v for k,v in conflicts.items()if v}
unique={k:v[0]for k,v in groups.items()};en={r['HAKSU_NO_BUNBAN']:r for r in json.loads((P/'skku-all-2026-2.json').read_text())['records']}
englishOnly=sorted(set(en)-set(unique));koreanOnly=sorted(set(unique)-set(en))
errors=[f.name for f in list(P.glob('skku-ko-major-courses-*.ssv'))+list(P.glob('skku-ko-general-*.ssv'))if b'ErrorCode:int=0\x1e'not in f.read_bytes()]
manifest={'majorRows':len(major['records']),'majorUnique':len({r['HAKSU_NO_BUNBAN']for r in major['records']}),'generalRows':len(general['records']),'combinedUnique':len(unique),'englishOnly':englishOnly,'koreanOnly':koreanOnly,'conflicts':conflicts,'responseErrors':errors,'degreeCounts':dict(Counter(r.get('JUKYONGHAKWI_GB')for r in unique.values())),'categoryCounts':dict(Counter(r.get('ISU_NAME')for r in unique.values())),'untimedIds':[k for k,r in unique.items()if not re.search(r'\d\d:\d\d',r.get('GYOSI_NAME',''))],'incompleteClockIds':[k for k,r in unique.items()if r.get('GYOSI_NAME','').count('【')!=r.get('GYOSI_NAME','').count('】')or r.get('GYOSI_NAME','').endswith(',')or (re.search(r'\d\d:\d\d',r.get('GYOSI_NAME',''))and not r.get('GYOSI_NAME','').endswith('】'))],'challengeIds':[k for k,r in unique.items()if r.get('HAKBU_JIBJUNG_GB')=='C'],'implementationComplete':False}
(P/'skku-ko-all-2026-2.json').write_text(json.dumps({'records':list(unique.values())},ensure_ascii=False,indent=2));(P/'skku-ko-audit.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in manifest.items()if k not in['untimedIds','conflicts']},ensure_ascii=False))
