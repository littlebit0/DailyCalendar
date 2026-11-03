import json,hashlib,struct,zlib,sys
from pathlib import Path
root=Path('work/university-research/resume-20261011')
sys.path.insert(0,'work/university-expansion/hwp-tools/lib/python3.9/site-packages');import olefile
p=root/'cnue/room-usage-guide.raw';o=olefile.OleFileIO(p);flags=struct.unpack_from('<I',o.openstream('FileHeader').read(),36)[0];texts=[]
for n in o.listdir():
 if n[0]!='BodyText':continue
 b=o.openstream(n).read();b=zlib.decompress(b,-15) if flags&1 else b;pos=0
 while pos+4<=len(b):
  v=struct.unpack_from('<I',b,pos)[0];pos+=4;tag=v&1023;size=v>>20
  if size==4095:size=struct.unpack_from('<I',b,pos)[0];pos+=4
  q=b[pos:pos+size];pos+=size
  if tag!=67:continue
  units=struct.unpack('<'+'H'*(len(q)//2),q[:len(q)//2*2]);i=0;chars=[]
  while i<len(units):
   c=units[i]
   if c in (1,2,3,9,11,12,14,15,16,17,18,21,22,23):i+=8;continue
   if c>=32:chars.append(chr(c))
   i+=1
  t=''.join(chars).strip()
  if t and '문의사항' not in t:texts.append(t)
(root/'cnue/room-usage-guide.text.json').write_text(json.dumps({'sourceOnly':True,'paragraphs':texts,'screenshotScenarioDate':'2021-11-22','nativeVisiblePeriodClocks':{'4':['12:10','13:00'],'5':['13:10','14:00'],'6':['14:10','15:00'],'7':['15:10','16:00'],'8':['16:10','17:00'],'9':['17:10','18:00'],'10':['18:10','19:00'],'11':['19:10','20:00'],'12':['20:10','21:00'],'13':['21:10','22:00'],'14':['22:10','23:00'],'15':['23:10','23:59']},'notVisiblePeriodClocks':['1','2','3'],'scope':'Currently pinned official room reservation guide using KOEDU undergraduate facility management UI; screenshot scenario is November2021. No inferred earlier periods or assumption of unchanged2026 teaching clock.'},ensure_ascii=False,indent=2)+'\n')
prior={'snue':'work/university-research/catalog-f/snue/snue-unknown-2026-2.native-held-partial-v1.json','cnue':'work/university-research/catalog-c/cnue-current-20261008/cnue-unknown-2026-2.published-partial-20261008.json'}
for school,path in prior.items():
 p=Path(path);d=json.loads(p.read_text());clock='Current undergraduate absolute period start/end table not confirmed; numbered labels alone insufficient.'
 obj={'verifiedDate':'2026-10-11','school':school,'priorCandidate':path,'priorCandidateSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'priorEducationalObjects':len(d['courses']),'newEligibleAppointments':0,'candidateCreated':False,'blockers':[clock],'sourceOnly':True,'productChanged':False,'sdkTestsBuildInstallUsed':False,'completionClaim':False,'impossibleClaim':False,'boundedFreshSearch':'Official domain restricted regular-class clock queries checked, excluding mock examinations, graduate calendars, elementary-school and other-university clocks. Current notice list loaded normally200. No repeated full prior document audit.'}
 if school=='snue':obj['blockers']+=['Two prior native weekday/grid disagreements and cumulative closure changes require adjudication after exact clocks are acquired.'];obj['priorCurrentScope']='2026-2 undergraduate 8class-group sheets, term8/31–12/11, explicit professors/rooms preserved.'
 else:
  obj['newEvidence']='Current pinned classroom reservation notice34091, officialHWP62567, native screenshot periods4–15 visible;2021scenario and absent1–3 do not establish full current2026 regular teaching clock.'
  obj['blockers']+=['Years3–4 practicum/intensive/holiday operating dates remain conditional, so standard entire-term recurrence must not be fabricated.']
  obj['priorCurrentScope']='Latest pinned2026-2 timetable41702 remains8/26 workbook;203 held regular educational items+5 dated CPR basic allocations.'
 (root/school/'resume-blocker-receipt.json').write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
