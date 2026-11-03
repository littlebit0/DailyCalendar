import json,re,collections,hashlib
from pathlib import Path
P=Path(__file__).parent;V1=P.parent/'ordinary-weekly-held-audit-20261008'
old=json.loads((V1/'khu-native-plan-screen.json').read_text()); prior={c['sourceId']:c for f in V1.glob('khu-*-2026-2.ordinary-reservation-research-v1-20261008.json') for c in json.loads(f.read_text())['courses']}
remote=re.compile(r'비실시간|비대면|실시간|온라인|원격|녹화|동영상|블[렌랜]디드|하이브리드|blended|flipped|asynchronous|online|remote|recorded|MOOC',re.I)
intensive=re.compile(r'집중(?:수업|강의|이수|학기|기간)|계절학기|집중강좌|intensive|학기\s*(?:전반|후반)|전반기|후반기',re.I)
exception=re.compile(r'현장(?:실습|학습|강의)|임상실습|인턴십|field\s*trip|internship|기관.*실습|실습.*기관',re.I)
kept=['priorExplicitBlendedFlippedAllocationUnconfirmed','nativeScheduleVariantConflict','nativeClockNotFullyParsed','nativeClockRoomMissingOrInvalid','currentPlanIdentityConflict','currentPlanPublishedNativeCodeConflict','currentPlanPublishedTeacherConflict','currentPlanNativeClockRoomMismatch']
out=[]
for d in old['decisions']:
 if prior[d['sourceId']]['schedules']:continue
 c=prior[d['sourceId']];reasons=[x for x in d['screenReasons'] if x in kept]; selected=[];signals=[]
 native=' '.join(str(v.get('bigo') or '') for v in c['sourceEducationalVariants'])
 if remote.search(native):reasons.append('nativeExplicitRemoteOperatingRemarks')
 if intensive.search(native):reasons.append('nativeExplicitIntensiveOperatingRemarks')
 if exception.search(native):reasons.append('nativeExplicitExternalOperatingRemarks')
 for pr in d['planProofs']:
  plan=json.loads(Path(pr['file']).read_text())
  for sec in plan['educationalSections']:
   if sec['section']=='수업유형 및 방법':
    method_header=None
    for row in sec['rows']:
     if '온라인강의' in row: method_header=row
     if row and row[0]=='수업방법' and method_header:
      index=method_header.index('온라인강의')
      if len(row)>index and str(row[index]).strip() not in ['','0','0%','0.0%']:
       reasons.append('currentPlanSelectedOnlineTeachingMethodUnallocated')
       selected.append({'row':row,'header':method_header,'selectedColumn':'온라인강의','actualDeliveryAllocationVerified':False})
   if sec['section']=='수업운영방식':
    for row in sec['rows']:
     if row and row[0]=='수업운영방식' and any(str(x).strip() not in ['','0','0%','0.0%'] for x in row[2:]):reasons.append('currentPlanSelectedRemoteOperatingMode');selected.append(row)
   if sec['section'] in ['수업운영방식','수업유형 및 방법','주별강의내용']:
    for row in sec['rows']:
     if not row:continue
     if row[0] in ['추가설명','수업유형추가설명','수업진행추가설명'] or (sec['section']=='주별강의내용' and re.fullmatch(r'\d+주',row[0])):
      text=' '.join(row[2:] if sec['section']=='주별강의내용' else row[1:])
      if remote.search(text):reasons.append('currentPlanExplicitRemoteOperation');signals.append({'section':sec['section'],'rowLocator':row[0],'kind':'remote'})
      if intensive.search(text):reasons.append('currentPlanExplicitIntensiveOperation');signals.append({'section':sec['section'],'rowLocator':row[0],'kind':'intensive'})
      if exception.search(text):reasons.append('currentPlanExplicitExternalOperation');signals.append({'section':sec['section'],'rowLocator':row[0],'kind':'external'})
 out.append({**d,'screenReasons':sorted(set(reasons)),'ordinaryReviewShortlistOnly':not reasons,'oldBroadTitleOrTypeHoldRemoved':True,'currentSelectedRemoteRows':selected,'actualOperationSignals':signals})
data={'priorScheduled':556,'remaining':len(out),'newShortlist':sum(d['ordinaryReviewShortlistOnly'] for d in out),'reasonCounts':dict(collections.Counter(x for d in out for x in d['screenReasons'])),'decisions':out,'completionClaim':False,'productionEdited':False,'SDKUsed':False,'interpretation':'Direct nativeHH:mm and room ordinary reservations; practical/PBL/capstone/project/individual-presentation titles or type percentages alone do not hold. Explicit actualremote/intensive/externaloperating text or nativeidentityclock conflict retains hold.'}
(P/'current-native-operating-screen.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in data.items() if k!='decisions'})
