"""Reviewed actual contexts. No word-based schedule approval; unresolved cases blocked."""
import json,hashlib,collections
from pathlib import Path
R=Path(__file__).resolve().parent
catalog={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education.json').read_text())}
files={p.stem:json.loads(p.read_text()) for p in (R/'cnu-current-education').glob('*.json')}
base=files['1155-7021-00']['header'][0]
chem_keys=('LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','LSN_RULE')
reviews=[]
for cid,j in files.items():
 if not j.get('planPresent'):continue
 h=j['header'][0];case=None
 if all(h.get(k)==base.get(k) for k in chem_keys):
  case={'kind':'currentPlanContradictoryDatedDelivery','scheduleAllowed':False,'blockReason':'Current face-to-face principle coexists with explicit mixed remote/in-person ranges whose weekday/date combinations belong to 2021 rather than 2026; current weekly table gives no disambiguating actual dates. Final exam time/place to be announced privately. Do not silently discard dated remote rules or reuse old dates.','educationFacts':{'currentMethod':'대면수업 원칙','otherPlanDateRule':'9.1.수~10.19.화 / 10.20.수~11.23.화 / 11.24.수~12.07.화','dateWeekdaysAgree2026':False,'examClockAndPlace':'추후 안내'}}
 elif cid.startswith('1001-8005-') and h.get('LSN_OPER_MTHD')==files['1001-8005-00']['header'][0].get('LSN_OPER_MTHD'):
  case={'kind':'asynchronousAndPartlyDatedLive','scheduleAllowed':False,'blockReason':'Plan requires VOD plus two live career sessions but prints only one live datetime. Exams must be taken at their specified times, but actual dates/times are absent from public weekly rows. Cannot claim complete timetable from the one known live event.','educationFacts':{'delivery':'VOD plus two live broadcasts','knownLiveEvent':{'date':'2026-10-07','startMinute':1080,'endMinute':1140,'deliveryMode':'liveOnline'},'otherLiveEventDateKnown':False,'examActualTimesKnown':False}}
 elif cid=='1001-8005-12':
  case={'kind':'faceToFaceAndUndatedLiveException','scheduleAllowed':False,'blockReason':'This section differs from other same-code sections: header says in-person, week4 names a required live career broadcast without actual date/time. Current course ending also absent. Do not reuse another section broadcast date.','educationFacts':{'currentMethod':'대면수업','week4ActualEvent':'CNU 미래대화 생방송','eventDateTimeKnown':False}}
 elif cid=='1001-8005-13':
  case={'kind':'currentPlanWrongSemesterExamMonths','scheduleAllowed':False,'blockReason':'This section differs from other same-code sections: VOD with online exams expressly described as April/June2026 despite current second-semester identity. Public plan does not resolve actual second-semester exam dates/times.','educationFacts':{'currentMethod':'동영상 온라인','printedExamMonths':['2026-04','2026-06'],'monthsMatch2026SecondSemester':False,'actualExamDateTimeKnown':False}}
 elif cid in ['1000-9581-00','1000-9582-00','1000-9583-00','1000-9584-00'] and h.get('LSN_OPER_MTHD')=='동영상으로 진행':
  case={'kind':'asynchronousNoFixedClock','scheduleAllowed':False,'blockReason':'Public current course has no displayed timetable, plan explicitly uses video, and weekly rows do not provide playback availability dates. Preserve untimed course without inventing fixed meetings or windows.','educationFacts':{'deliveryMode':'asynchronous','catalogDisplayedClock':catalog[cid].get('TMTBL_INFO'),'actualWindowDatesKnown':False}}
 elif cid=='1001-7038-00':
  case={'kind':'datedVODMakeupWithoutFullDateRule','scheduleAllowed':False,'blockReason':'Week5 explicitly names Dec8 video makeup; Monday displayed clock cannot be copied to this Tuesday VOD event. Other week actual dates/course ending not printed, so full calendar projection remains unconfirmed.','educationFacts':{'defaultDelivery':'inPerson','conditionalRemotePolicy':'감염 등 부득이한 경우','actualMakeupNote':'보강주 동영상(12월 8일)','makeupDate':'2026-12-08','makeupDeliveryMode':'asynchronous','actualMakeupClockKnown':False}}
 if case:
  case.update(courseId=cid,title=catalog[cid]['SBJT_NM'],sourceResponseSHA256=j['sourceResponseSHA256'],currentNativeClassification=catalog[cid]['CPTN_DIV_CD_FNM'],currentOriginalTimetable=catalog[cid].get('TMTBL_INFO'),semanticContextReviewed=True)
  reviews.append(case)
(R/'cnu-reviewed-operation-cases-20261008.json').write_text(json.dumps({'reviews':reviews,'counts':dict(collections.Counter(r['kind'] for r in reviews)),'wholeReviewComplete':False,'unreviewedRemainSeparatelyPending':True,'sourceWholeTopicsStoredInCandidate':False},ensure_ascii=False,indent=2))
print('reviewed',len(reviews),dict(collections.Counter(r['kind'] for r in reviews)))
