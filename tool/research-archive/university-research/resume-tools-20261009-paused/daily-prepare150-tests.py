from pathlib import Path
import json,re
B=Path('work/university-research');K=B/'catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1'
folders=[K/x for x in ['packet043-reviewed30','packet044-reviewed30','packet045-reviewed30','packet045b-one-explicit-live']]+[B/'catalog-v'/x for x in ['changwon-native-live-weekly-plan-review-v7b-20261009','changwon-conditional-video-default-physical-review-v8b-20261009']]
paths=[]
for folder in folders:
 p=next(folder.glob('*.dart.txt'));s=p.read_text();s=re.sub(r"schoolRemaining\s*\+\s*'\\n'\s*\+\s*'([^']*)'",lambda m:"'$schoolRemaining\\n"+m.group(1)+"'",s)
 for var in ['q','proof']:
  s=s.replace("e.value + '\\n' + "+var+"['exactAddedResearchNotice']",'"${e.value}\\n${'+var+"['exactAddedResearchNotice']}\"")
 out=p.with_name(p.name.replace('.dart.txt','_root_actual_test.dart'));out.write_text(s);paths.append(str(out))
Path('/tmp/daily-checkpoint150-source-test-files.json').write_text(json.dumps(paths));print('150 source fixtures prepared',len(paths))
