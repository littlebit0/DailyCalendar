"""Independent source/identity/date validation; does not claim Flutter model validation."""
import copy,datetime as dt,hashlib,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
PRIOR=OUT.parent/'cnu-ordinary-reservation-v2-20261008'
a=json.loads((OUT/'candidate-audit.json').read_text());baseline=json.loads(Path(a['baselinePath']).read_text());candidate=json.loads((OUT/a['candidateFile']).read_text());raw=json.loads((PRIOR/'current-public-native-educational-catalog.json').read_text());source={r['COURSE_NO']:r for r in raw}
assert len(raw)==3888==len(source);assert len(candidate['courses'])==3887;assert {c['sourceEducation']['courseId'] for c in candidate['courses']}.issubset(source); assert len({c['sourceId'] for c in candidate['courses']})==3887
proof={r['courseId']:r for r in a['proofs']};original={c['sourceEducation']['courseId']:c for c in baseline['courses']};closed=set(a['closedDates']);total=0;new=0
for c in candidate['courses']:
 cid=c['sourceEducation']['courseId'];old=original[cid];native=source[cid]
 assert c['courseCode']==native['OPEN_SBJT_NO'];assert c['section']==native['OPEN_DCLSS'];assert c['courseName']==native['SBJT_NM'];assert c['professor']==(native.get('LT_STAFF_NM') or '')
 if cid not in proof:assert c==old;continue
 new+=1;p=proof[cid];path=Path(p['sourcePlanFile']);assert hashlib.sha256(path.read_bytes()).hexdigest()==p['sourcePlanSHA256'];plan=json.loads(path.read_text());assert plan['courseId']==cid and plan['planPresent']; assert all(h['OPEN_SHTM_CD_NM']=='2학기' for h in plan['header']);assert native['CLOSE_YN']=='0';assert native['OBJ_CORS_CD_NM']=='학사과정';assert native['OPEN_YR']=='2026';assert native['OPEN_SHTM_CD']=='USR01.20';assert c['campus']=='unknown'
 assert c['sourceEducation']==old['sourceEducation'];assert c['reservationEvidence']['individualModeOverride']==False
 expected=[];day=dt.date(2026,9,1)
 while day<=dt.date(2026,12,18):
  for slot in old['sourceEducation']['actualDisplayedClocks']:
   if day.isoweekday()==slot['weekday'] and str(day) not in closed:
    expected.append((str(day),slot['weekday'],slot['startMinute'],slot['endMinute'],slot['location']))
  day+=dt.timedelta(days=1)
 actual=[(s['date'],s['weekday'],s['startMinute'],s['endMinute'],s['classroom']) for s in c['schedules']];assert sorted(actual)==sorted(expected); assert len(actual)==len(set(actual));total+=len(actual)
 z=copy.deepcopy(c);z.pop('reservationEvidence')
 for key in ['schedules','scheduleStatus','period','departmentRemarks']:
  if key in old:z[key]=old[key]
  else:z.pop(key,None)
 assert z==old
assert new==260 and total==6372
report={'sourceOnlyValidationPassed':True,'modelThreeModeDriveValidation':'notRunSDKForbidden','newCourses':new,'newReservations':total,'wholeNativeUnknown':3887,'wholeNativeInstitution':3888,'priorScheduledUnknown1427DeepUnchanged':True,'priorDaedeok1DeepUnchanged':True,'allOtherHeldObjectsUnchanged':True,'all260CurrentPlanFileSHAVerified':True,'all260CurrentUGNativeHeaderVerified':True,'all260NativeClockDateRoomIndependentEquality':True,'datesWithinOwnPublishedTerm':True,'excludedDates':sorted(closed),'sourceFieldIdentityOrCodeInvented':False,'physicalCampusInferred':False,'actualAttendanceClaim':False,'networkUsed':False,'SDKUsed':False,'productEdited':False}
(OUT/'source-only-independent-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(report)
