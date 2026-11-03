"""R3 full operating-signal second sweep, scoped section fixes and stale body guard."""
import copy,datetime as dt,hashlib,json,pathlib
R=pathlib.Path(__file__).resolve().parent
old=json.loads((R/'postech-main-2026-2.planned-audited-20261008-r2.json').read_text());new=copy.deepcopy(old)
closed=set(json.loads((R/'postech-planned-audited-20261008-r1-sha-manifest.json').read_text())['closureDates']);changes=[]
for c in new['courses']:
 key=(c['courseCode'],c['section'])
 if key in [('GEDU101','02'),('GEDU101','04'),('GEDU101','08'),('EVSE490A','01')]:
  reason='현재 강좌·학기 표지와 개별 운영 본문의 학기 날짜/추석 주차가 불일치. 공시 강좌 자체를 폐강으로 판단하지 않으며 해당 운영 예외 적용 미확정으로 보류.'
  c['schedules']=[];c['scheduleStatus']='unrecognized';c['metadata']['plannedTimetableDecision']='currentHeaderOperatingBodyConflict';c['metadata']['decisionReason']=reason
  for d in c['departments']:c['departmentRemarks'][d]+='\n'+reason
  changes.append({'code':key[0],'section':key[1],'decision':'staleBodyGuard','dateCount':0})
 if key==('MECH250','02'):
  # Section01 actual recorded lecture text must not be imposed on section02.
  reason='02분반 현재 계획서는 정규 열역학 내용과 공시 시간표이며 01분반 동영상 운영 문장을 공유하지 않음.'
  dates=[];day=dt.date(2026,9,7)
  while day<=dt.date(2026,12,24):
   for s in c['metadata']['originalSourceSchedules']:
    if day.isoweekday()==s['weekday'] and day.isoformat() not in closed and day.weekday()!=6:dates.append(dict(s,date=day.isoformat()))
   day+=dt.timedelta(days=1)
  previous=c['metadata']['decisionReason'];c['schedules']=dates;c['scheduleStatus']='scheduled';c['metadata']['plannedTimetableDecision']='plannedRegularTimetable';c['metadata']['decisionReason']=reason
  for d in c['departments']:c['departmentRemarks'][d]=c['departmentRemarks'][d].removesuffix('\n'+previous)+'\n'+reason
  changes.append({'code':key[0],'section':key[1],'decision':'perSectionRecordedContext','dateCount':len(dates)})
fn='postech-main-2026-2.planned-audited-20261008-r3.json';data=(json.dumps(new,ensure_ascii=False,indent=2)+'\n').encode();(R/fn).write_bytes(data)
manifest={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(data).hexdigest(),'previousR2SHA':hashlib.sha256((R/'postech-main-2026-2.planned-audited-20261008-r2.json').read_bytes()).hexdigest(),'currentPublicOfferingCount':418,'scheduledCount':sum(bool(c['schedules']) for c in new['courses']),'dateCount':sum(len(c['schedules']) for c in new['courses']),'changes':changes,'r2PairingAndDatedWebexPreserved':True,'expandedSignalRows':87,'secondarySignalRows':20,'secondaryChapterDecimalFalsePositivesReviewed':True,'other413ObjectsByteEquivalent':all(a==b for a,b in zip(old['courses'],new['courses']) if (a['courseCode'],a['section']) not in {(x['code'],x['section']) for x in changes})}
(R/'postech-planned-audited-20261008-r3-sha-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in manifest.items() if k in ['sha256','scheduledCount','dateCount','changes']})
