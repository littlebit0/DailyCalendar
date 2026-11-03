"""Retain confirmed meetings of three split source timetables, holding the others."""
import pathlib,json,copy,hashlib,importlib.util,datetime as dt
R=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('hknu',R.parents[2]/'tool/timetable/import_hknu.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
ends={1:'2026-12-21',2:'2026-12-08',3:'2026-12-09',4:'2026-12-17',5:'2026-12-18',6:'2026-12-19',7:'2026-12-21'}
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
files=[];changed=[]
for campus in ['anseong','pyeongtaek']:
 d=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r3.json').read_text())
 for c in d['courses']:
  if c['schedules'] or c['scheduleStatus']!='unrecognized' or 'currentFinalPublishedCancellation' in c['metadata']:continue
  valid=[];unresolved=[]
  for part in c['sourceSchedule'].split(' / '):
   slots,reason=mod.clocks(part,c['sourceClassroom'])
   if slots:valid+=slots
   else:unresolved.append({'originalPublishedRange':part,'reason':reason})
  if not valid or not unresolved:continue
  assert c['courseCode'] in {'0000250078','1000230015','0000033423'}
  dated=[]
  for slot in valid:
   day=dt.date(2026,9,1);end=dt.date.fromisoformat(ends[slot['weekday']])
   while day<=end:
    if day.isoweekday()==slot['weekday'] and day.isoformat() not in holidays:dated.append(dict(slot,date=day.isoformat()))
    day+=dt.timedelta(days=1)
  c['schedules']=dated;c['scheduleStatus']='scheduled';c['metadata']['publishedWeeklyMeetingsUsedForPlan']=valid;c['metadata']['partialClockOnlyConfirmedParts']=True;c['metadata']['unresolvedOtherPublishedMeetings']=unresolved
  c['departmentRemarks'][c['departments'][0]]+='\n공시 시각 중 해석이 확인된 회의만 일부 추가: '+', '.join(u['originalPublishedRange'] for u in unresolved)+' 시각은 미확정이라 반영하지 않음. 강좌 전체 출석 회의 완료가 아님.'
  changed.append({'sourceId':c['sourceId'],'confirmedDateCount':len(dated),'unresolvedOtherMeetings':unresolved})
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r4.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
assert len(changed)==3
m=json.loads((R/'hknu-planned-audited-20261008-r3-sha-manifest.json').read_text());m['files']=files;m['partialClockOnlyConfirmedPartChanges']=changed;m['totalScheduledCount']=sum(x['scheduledCount'] for x in files);m['totalDateCount']=sum(x['dateCount'] for x in files);m.pop('allClocksDatesModesIdentitiesOtherEducationUnchangedFromR2',None)
(R/'hknu-planned-audited-20261008-r4-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files)
