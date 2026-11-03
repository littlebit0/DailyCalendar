import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1004-7005-00':('weeklyVideoWindowWithoutActualPeriod','Actualremote theoryvideo weeklyTue00:00–Mon23:59 andliveZoompractical. Week1videoonly, week8/15inpersonexamsatpracticaltime. CurrentThu/Fri2h slotsnotdirectlyassigned theory/live practical; actualteachingweeksdates andexamdatesnotprinted, so noautomaticwindows orordinarytime generated.'),
'1005-7003-02':('supplementaryLectureNoteNotMakeupMeeting','보충강의안 meanssupplementarycivil-lawlecture notes uploaded, notactualcanceledclassreplacement.2026Augustedition istextbookpublicationnotlecturedate. Actualnormalperiod/examspending.'),
'1102-7018-00':('makeupMeansTopicReviewNotConfirmedCalendarReplacement','Week14Makeup explicitlycompletesunfinishedweeks11/13content. Currentinpersonweekly1-7/9-14, exams8/15, mirroringifclassroomallows. Do nottranslateMakeupintoofficialcentralholidayreplacement date. Actualindividualdates/endperiodunknown.'),
'1104-7003-03':('September24SameDayVideo','CurrentinpersonTue/Thu, exactSep24same-dayVODholidaymakeup. NoDec10automaticclassroomreplacement; actualvideowindowclock notprinted. Normalperiodpending.'),
'1104-2011-00':('actualClock50MinuteOverrideAndConditionalMakeup','MethodactualMon15-15:50/Wed12-13:50 overridesnormalcatalog60/120min; teampartsweek1-8 and9-15notdates. Remoteonlyifadvance2weeksnoticeforholidaymakeup; actualperiod/makeupmode/dateunknown.'),
'1104-3005-00':('September24VideoAndDifferentWeekdayRemoteField','ActualTue12-12:50/Thu12-13:50source versuscatalog60/120minutes. ExactSep24video same-day, remotefieldWednesdaylive disagreescurrentTue/Thu. NoDec10inpersoncopy, videoactualwindow/currentperiodpending.'),
'1105-7005-01':('holidayRemoteOnOriginalDayOverridesCentralWeek','Explicitholidayclassremotelysame-day, notendtermreplacementweek. Separate90%VOD/10%irregularZoomfieldneedsapplicabilityreview, noactualindividualvideo/livewindows. Donotusecommoncentralreplacementdate.'),
'1106-1005-00':('designatedMakeupWeekButActualMeetingUnknown','Currentinperson pluspreannouncedsupplementvideo, holidaymakeup school-designatedweek. Thissupportsdatepolicybutdoesnotdirectlyfixindividualactualclock/mode/place/endperiod. Actualwholecoursecannotderivefromcommonweekonly.'),
'1106-7003-00':('currentInpersonAndHistorical2021Remote','CurrentinpersonweeklywithfirstweekOTactualteachingbutnotattendancecount; designatedholidaymakeup week14. Separateexplicit2021-2remote/recordingfieldhistorical. Currentactualperiodandindividualreplacementtimeunknown; attendance-not-countedfirstweekmustnotmeansnoclass.'),
'1106-7003-01':('threeDifferentWeekdaySetsAndReplacementVideo','CurrentcatalogTue/Thu, methodWed/Friinperson, remotefieldMon/Thulive; nocurrentweekdayprecedence. Canceledclassesreplacedcyberlecture, firstsecondsession/examweekvideotasks. Noactualmode/window/datecreationuntilreconciled.')}
reviews=[]
for cid,(kind,text) in cases.items():
 d=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());reviews.append({'courseId':cid,'sourceResponseSHA256':d['sourceResponseSHA256'],'currentDisplayedClockRoom':d['header'][0].get('TLSN_ANNM',''),'classification':kind,'finding':text,'scheduleAllowed':False,'selectedEducationalCacheScope':'Preserved whitelist fields only; original neighboring text may be lost by oldcontact-line removal. No full-originalabsence claim.'})
(R/'cnu-reviewed-ten-further-makeup-contexts-20261008.json').write_text(json.dumps({'wholeSemanticReviewComplete':False,'fullCacheReusedNoRefetch':True,'reviews':reviews},ensure_ascii=False,indent=2)+'\n')
p=R/'build_cnu_structural_review_queue.py';s=p.read_text().replace("for filename in ['cnu-reviewed-twelve", "for filename in ['cnu-reviewed-ten-further-makeup-contexts-20261008.json','cnu-reviewed-twelve");p.write_text(s)
print('10 further operating contexts reviewed individually; common makeup rules not overextended')
