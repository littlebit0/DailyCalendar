"""Manual educational meaning review of observed no-class/makeup contexts, not approval."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
D={}
def put(ids,kind,note,facts=None):
 for cid in ids.split():D[cid]={'courseId':cid,'semanticReviewCompleteForObservedException':True,'kind':kind,'educationNote':note,'facts':facts or {},'scheduleAllowed':False,'remainingGate':'Entire actual course date/operation verification remains pending'}
put('1102-3004-00','holidayMonthMismatch','Plan says Chuseok Oct7/Oct9, inconsistent with actual2026 Chuseok Sep24–26. Makeup undecided. Do not reuse previous-year holiday dates.')
put('1104-2002-00 1104-7001-02','datedCyberMakeup','Oct5 holiday lesson to be made up on cybercampus on same day; synchronous versus asynchronous timing not specified.',{'date':'2026-10-05','specificTimeKnown':False})
put('1104-4011-00 1104-7005-00','datedCyberMakeup','Sep24 holiday lesson to be made up on cybercampus on same day; synchronous versus asynchronous timing not specified.',{'date':'2026-09-24','specificTimeKnown':False})
put('1104-4014-01','datedVODAndUnannouncedMakeup','Sep25 explicitly video makeup on same day. Oct9 makeup will be announced; no actual clock/window available.',{'asynchronousDate':'2026-09-25','undecidedMakeupFor':'2026-10-09'})
put('1105-2018-00','holidayWeekConflict','Week3 Sep16/Sep21 marked Chuseok although actual holiday Sep24–26. Plan also says later makeup notice, so do not silently normalize week labels.')
put('1105-7004-01','unannouncedMakeup','Dec8–11 is institution designated window, actual course makeup datetime to be announced. Window is not four fixed lessons.')
put('1105-7004-02','unannouncedMakeup','Sep24 no class; one makeup expected, actual date to be announced during Dec8–11. No individual makeup time invented.',{'noClassDate':'2026-09-24'})
put('1108-3001-00','holidayNoClassWeekWithoutDates','Week4 only says Chuseok holidays; no specific lesson date/makeup proof. Do not generate ordinary classroom lessons from topic-free row.')
put('1109-3017-00','dateWeekdayConflict','Oct22 exam-week no class. Dec9 printed as Thursday but actual2026 is Wednesday; actual final-week schedule remains unresolved.',{'noClassDate':'2026-10-22','conflictingDate':'2026-12-09','printedWeekday':4,'actualWeekday':3})
put('1109-4010-00','unannouncedMakeup','Sep24 lesson to be made up later; datetime absent.',{'noClassDate':'2026-09-24'})
put('1109-7008-01','printedDatedScheduleWithConflicts','Sep24 recorded lecture, Oct22 and Dec10 exam-week no class. Printed Nov3/Nov24 called Monday despite actual Tuesday; current source needs resolution, no date auto-correction.',{'recordedDate':'2026-09-24','noClassDates':['2026-10-22','2026-12-10'],'weekdayConflicts':['2026-11-03','2026-11-24']})
put('1111-2014-00','holidayAndFieldtripNoClass','Week4 Chuseok no class and Dec10 makeup planned; week5 no class for department fieldtrip. Actual fieldtrip/makeup times not printed.',{'makeupDate':'2026-12-10','specificMakeupClockKnown':False,'fieldtripDateKnown':False})
put('1112-7001-02','remoteMakeupWeek','Week9 explicitly remote makeup; current plan lacks actual datetime and delivery synchronization mode.')
put('1136-7003-00','datedRemoteHolidayMakeup','Sep25 and Oct9 remote holiday makeup named, no actual fixed clock or VOD windows.',{'dates':['2026-09-25','2026-10-09'],'specificTimesKnown':False})
put('1151-2007-01 1151-7009-08','unresolvedAlternativeMakeup','Oct5 lesson will be video or taught during makeup week. Two alternatives not finalized, do not choose one.',{'originalDate':'2026-10-05','chosenMethodKnown':False})
put('1156-1002-00','examWeekNoClass','Week8 says midterm(no class). Date/start/end and exam participation method not printed; no ordinary classroom lesson invented.')
put('1191-4009-00','datedHolidayNoClass','Explicit0925 Friday Chuseok no class; makeup information absent.',{'noClassDate':'2026-09-25'})
put('1106-2002-00 1106-3008-00 1109-2013-00 1131-1002-00 1131-3003-00 1131-3009-00 1132-2009-00 1151-4003-00 1151-7009-23 1158-2007-00 1194-2006-00','genericMakeupOrExamWithoutActualDates','Row says makeup/review/exam without actual datetime. Does not itself establish cancellation or a separate date; full source date bound still needed.')
put('1107-3011-00 1153-4034-00 1191-5006-00 1192-3003-00 1192-3003-02 1194-4011-00','educationalTopicFalsePositive','Observed token refers to poem/title, strengthening project topic, structural reinforcement or maintenance, not class cancellation/makeup. Do not treat educational subject as timetable change.')
rows=[]
for cid,d in sorted(D.items()):
 p=R/'cnu-current-education'/f'{cid}.json';assert p.exists()
 j=json.loads(p.read_text());d['sourceResponseSHA256']=j['sourceResponseSHA256'];rows.append(d)
(R/'cnu-reviewed-week-exceptions-20261008.json').write_text(json.dumps({'reviews':rows,'wholeSemanticReviewComplete':False,'actualExceptionReviewCount':len(rows),'dateRepairsInvented':False,'educationalTopicsOrFullPlansInCandidate':False},ensure_ascii=False,indent=2));print('reviewed observed contexts',len(rows))
