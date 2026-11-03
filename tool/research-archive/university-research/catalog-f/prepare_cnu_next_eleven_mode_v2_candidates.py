"""Normalize only school-confirmed dated modes; original educational data stays intact."""
import json,hashlib,copy
from pathlib import Path
R=Path(__file__).resolve().parent
sources=['cnu-daedeok-2026-2.whole-checkpoint.json','cnu-unknown-2026-2.whole-checkpoint-next-eleven-openinglive-partial.json']
targets=['cnu-daedeok-2026-2.whole-checkpoint-next-eleven-mode-v2.json','cnu-unknown-2026-2.whole-checkpoint-next-eleven-mode-v2.json']
changed=0;rows=0;courses=0;meetings=0;files={}
for src,target in zip(sources,targets):
 old=json.loads((R/src).read_text());new=copy.deepcopy(old);rows+=len(new['courses'])
 for previous,current in zip(old['courses'],new['courses']):
  if current['scheduleStatus']=='scheduled':
   courses+=1;meetings+=len(current['schedules'])
   for before,after in zip(previous['schedules'],current['schedules']):
    if before.get('mode')=='inPerson':
     assert before.get('deliveryMode') in (None,'inPerson')
     after['deliveryMode']='inPerson';changed+=1
    else:assert before.get('deliveryMode')=='liveOnline'
    stripped=copy.deepcopy(after)
    if 'deliveryMode' not in before:stripped.pop('deliveryMode',None)
    assert stripped==before
  stripped=copy.deepcopy(current);stripped['schedules']=previous['schedules'];assert stripped==previous
 new['verificationScope']=old.get('verificationScope','')+'; only confirmed dated school modes normalized to model deliveryMode, all original dates/clocks/rooms/remarks/source education unchanged'
 path=R/target;path.write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');files[target]=hashlib.sha256(path.read_bytes()).hexdigest()
assert rows==3888 and courses==11 and meetings==171 and changed==170
(R/'cnu-next-eleven-mode-v2-candidate-audit.json').write_text(json.dumps({'filesSHA256':files,'wholeRows':rows,'scheduledCourses':courses,'datedMeetings':meetings,'schoolConfirmedInPersonModesNormalized':changed,'existingLiveOpeningClassUnchanged':True,'allOriginalSourceEducationRestrictionsRemarksDatesClocksRoomsUnchanged':True,'originalModeFieldsRetained':True,'wholeSemanticReviewComplete':False},indent=2))
print(files)
