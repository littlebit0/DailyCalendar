"""Reviewed printed-date context conflicts, distinct from unresolved collection."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent
cases={
'1104-7001-02':('currentWeekdayAndDeliveryConflict','Current full in-person Mon/Wed dates coexist with remote Wed/Fri paragraph and video-open attendance requirement. Oct5 cyber makeup timed method unknown; final weekly work may be cyber. Full actual fixed delivery not confirmed.'),
'1104-7005-00':('currentDatedDeliveryAndLegacyDateConflict','Current Tue/Thu dates and different rooms explicit; remote paragraph retains2021 Wed/Fri dates; week5 contains April3 date and later possible videos. Sep24 cyber makeup method/time unknown. Do not discard mixed-source inconsistencies.'),
'1105-7004-01':('currentWeekdayAndDeliveryConflict','Current Tue/Wed printed dates include Sep14 Monday instead of Tuesday. Remote paragraph retains Friday6/7 and Tuesday1 with different actual times. Current method and one date unresolved.'),
'1137-2027-00':('currentDatedTakeHomeAndUndatedLastWeeks','Printed Mon/Tue dates through Dec1 coexist with mixed-live statement and week-long take-home exam rule. Weeks11/15 lack specific actual dates. Do not turn take-home windows into classroom exam meetings.'),
'1101-2012-00':('datedVODHolidayAndMissingDateSeparators','Plan explicitly replaces holiday makeup with online videos. Oct5 has no actual playback window; two early dates use comma notation and exam period not necessarily classroom instruction. Entire operation not fully timed.'),
'1102-3017-00':('currentClockConflictsWithExplicitRemoteHour','Current Mon/Thu timetable coexists with explicitTuesday 17–18 live online and remaining recorded instruction. One hour method discussed first week; actual teaching mode/date assignment unresolved. Printed exam start alone does not prove endtime.'),
'1102-3017-01':('currentClockConflictsWithExplicitRemoteHour','Current Tue13–15 / Thu14–15 timetable coexists with Tuesday 17–18 live online and remaining recorded instruction. One class shifted to Oct1 but actual clock/delivery assignment unresolved. Exam start alone is not end-time proof.')}
rows=[]
for cid,(kind,note) in cases.items():
 j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());rows.append({'courseId':cid,'kind':kind,'educationNote':note,'sourceResponseSHA256':j['sourceResponseSHA256'],'observedContextReviewed':True,'scheduleAllowed':False,'actualGateUnresolved':True})
(R/'cnu-reviewed-dated-conflicts-20261008.json').write_text(json.dumps({'reviews':rows,'count':len(rows),'wholeSemanticReviewComplete':False,'unreviewedStillSeparate':True},ensure_ascii=False,indent=2));print('reviewed dated conflicts',len(rows))
