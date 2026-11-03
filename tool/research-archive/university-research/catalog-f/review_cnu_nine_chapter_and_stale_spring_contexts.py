"""Candidate date hits reviewed by actual topic/operation context, not string rules."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1151-2011-00':('chapterNumbersNotDates','6.1–7.3 are Riemann integral/calculus textbook sections. CurrentMon/Wed lecture/presentation andweek4test/week15final known, but actual teachingperiod/examdates unknown.'),
'1151-2011-01':('chapterNumbersNotDates','6.1–7.3 are textbook chapters, notJune/July meetings. CurrentMon/Wed clockdiffersfromsection00; do notcopyroom/clock. Individualactualperiod/examdates pending.'),
'1343-1010-00':('chapterNumbersAndConditionalRemote','2.3/2.5/3.2 etc are Ch integer/congruence sections. Inpersondefault and inpersonmid/final; remote onlyifinpersonimpossible ordistancing4. Noactualfinaldate orindividualperiodprinted inpreservedfields.'),
'1343-2009-00':('chapterNumbersAndConditionalRemote','6.1/6.3/7.1… are integral/convergence textbook sections; currentThu/Tue fixedinstructioninpersondefault, online onlyifneeded. Actualfinal/period notconfirmed.'),
'1381-2009-00':('springVideoWindowsOutsideCurrentFallCover','Printed video windows March22Sun–28Sat, March29Sun–April4Sat, March15Sun–21Sat are outside current fall term. Their weekday pattern can match2026, so no old-year inference is asserted; printed year/current applicability is unconfirmed. Weekly3/4 dates repeat1/2 makeupwindows outoforder. Currentinpersonmethod versushomeVODfield unresolved; cannotreuse springvideoavailabilityin2026fall.'),
'1206-1004-00':('chemistryChaptersAndOnline40MinuteOperation','10.1–12.7 are chemistry chaptersnotteachingdates. Methodremote explicit2online40min/week conflicts currentMon/Wed90minclock; online livevsVOD andcurrentpolicy applicabilitynotdirectlyset. Do notcreate current90minactualremote or40minattendance dates.'),
'1206-1004-01':('chemistryChaptersAndOnline40MinuteOperation','Same chemistrychapterfalse-date contextas00 butcurrentTue/Thu90minslot. Separate40min2online/week doesnotfixmode/window/clockplacement; actualcurrentperiod/examsunknown.'),
'1251-2010-00':('topicPartFractionsAndExplicitAttendanceSplit','1/2 and2/2 are two-parttopicfractions. Currentmethod2hinperson+1hZoomQ&A withnoattendancecheckforQ&A, alternatehomecourse/finalonlyinpersonfield conflicts. CurrentThu2h/Fri1hmatchesdurationsbutdoesnotdirectlyassignmodeweekday. Actualindividualperiod/examdatesunknown.'),
'1000-9301-00':('explicitSpringIntensiveAndNoClassPlacement','PlanexplicitMarchinstruction,5-10weekseducationplacement noordinaryclass, Mayend/Juneearly2weeks,June3election andJune10/17 reflection. AlloutsidecurrentSep-Dec term; currentMondayclockcannotcopyJuneWednesdaydates. Orientation andrecordedmicroteachingattendance substitute credited2h/1h withoutactualcurrentdates/windows. No fallwholeweeklyinstructionderived.')}
reviews=[]
for cid,(kind,text) in cases.items():
 d=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());reviews.append({'courseId':cid,'sourceResponseSHA256':d['sourceResponseSHA256'],'currentDisplayedClockRoom':d['header'][0].get('TLSN_ANNM',''),'classification':kind,'finding':text,'scheduleAllowed':False,'selectedEducationalCacheScope':'Preserved selected education only; no full-original absence proof because old contact-line removal can omit neighboring context.'})
(R/'cnu-reviewed-nine-chapter-and-stale-spring-contexts-20261008.json').write_text(json.dumps({'wholeSemanticReviewComplete':False,'fullCacheReusedNoRefetch':True,'reviews':reviews},ensure_ascii=False,indent=2)+'\n')
p=R/'build_cnu_structural_review_queue.py';s=p.read_text().replace("for filename in ['cnu-reviewed-seven-date", "for filename in ['cnu-reviewed-nine-chapter-and-stale-spring-contexts-20261008.json','cnu-reviewed-seven-date");p.write_text(s)
print('Nine full selected operation contexts interpreted; no extra dates generated')
