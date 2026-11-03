"""Independent no-SDK native-row, literal-clock/date and preservation review."""
import json, hashlib, datetime, re
from pathlib import Path
R=Path(__file__).resolve().parent
def read(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
proof=read(R/'independent3-native-source-proof.json')
rules={'MGT4090-01':(1,720,780,''),'CFTD088-01':(4,810,885,'50305'),'CFTD086-01':(4,1080,1150,'31506')}
expected_dates={1:['09-07','09-14','09-21','09-28','10-12','10-19','11-02','11-09','11-16','11-23','11-30','12-07'],4:['09-03','09-10','09-17','10-01','10-08','10-15','10-22','10-29','11-05','11-12','11-19','11-26','12-03','12-10','12-17']}
for p in proof:
 assert sha(p['currentOperatingEducationPath'])==p['currentOperatingEducationSHA256']
 assert read(p['currentOperatingEducationPath'])==p['ownOperatingRecord']
 assert sha(p['originalNativeEducationPath'])==p['originalNativeEducationSHA256']
 native=p['originalNativeRow'];key=p['nativeCodeSection'];weekday,start,end,room=rules[key]
 clock=native['요일/교시']if key=='MGT4090-01'else native['GYOSI_NAME']
 if key=='MGT4090-01':
  raw=re.search(r'\((\d+):(\d+)\).*\((\d+):(\d+)\)',clock);assert raw; hh=list(map(int,raw.groups()));assert(hh[0]*60+hh[1],hh[2]*60+hh[3])==(start,end)
  assert native['강의실']is None and native['집중이수학기기간']is None
 else:
  raw=re.search(r'(\d+):(\d+)-(\d+):(\d+)',clock);assert raw;hh=list(map(int,raw.groups()));assert(hh[0]*60+hh[1],hh[2]*60+hh[3])==(start,end)
  assert room+'호'in native['BIGO'] and native['HAKBU_JIBJUNG_GB']=='N'and native['SUUP_TYPE_CD']=='33'
  assert '사전제작'in native['SUUP_TYPE_NM']and 'OFF'in clock
 for d in expected_dates[weekday]:assert datetime.date.fromisoformat('2026-'+d).isoweekday()==weekday
counts=[];unchanged=0;added=0
for name in ['dongguk-seoul-2026-2','skku-humanities-2026-2']:
 before=read(R/(name+'.baseline118.json'));after=read(R/(name+'.room-only-ordinary-candidate.json'));assert len(before['courses'])==len(after['courses'])
 for old,c in zip(before['courses'],after['courses']):
  key=c['courseCode']+'-'+c['section']
  if key not in rules:assert old==c;unchanged+=1;continue
  added+=1;weekday,start,end,room=rules[key]
  assert c['schedules']==[{'date':'2026-'+d,'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room}for d in expected_dates[weekday]]
  for k in old:
   if k in['schedules','scheduleStatus','metadata','unresolvedReasons','period']:continue
   assert old[k]==c[k],(key,k)
  if key=='MGT4090-01':
   m=dict(c['metadata']);o=dict(old['metadata']);assert m.pop('heldReasons')==[]and o.pop('heldReasons')==['실제 강의실 미공개'];assert m==o;assert c['professor']==c['sourceClassroom']==''and c['period']==old['period']
  else:assert c['sourceEducationalMetadata']==old['sourceEducationalMetadata']and c['sourceClassroom']=='미지정'
 counts.append({'file':name,'courses':len(after['courses']),'scheduled':sum(bool(c['schedules'])for c in after['courses']),'dated':sum(len(c['schedules'])for c in after['courses'])})
assert added==3 and unchanged==3826
all_receipts=read(R/'all-current-native-catalog-file-receipts.json');assert len(all_receipts)==145
assert all(sha(r['file'])==r['sha256']for r in all_receipts)
result={'sourceValidation':'PASS','sdkExecuted':False,'productChanged':False,'originalNativeRowsJoined':3,'allOtherWholeObjectsPreserved':3826,'addedDatedMeetings':42,'counts':counts,'all145ProductCatalogSHAsUnchangedSinceAudit':True,'completionClaim':False,'wholeOperatingVerified':False,'fullNativeCFTD086HWPXSHAAvailable':False}
(R/'actual-source-only-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
