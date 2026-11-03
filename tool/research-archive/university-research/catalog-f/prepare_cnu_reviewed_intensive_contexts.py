"""Reviewed fixed-duration/independent service contexts without fabricating dates."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent;cases=[]
def add(cid,kind,note):
 j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());cases.append({'courseId':cid,'kind':kind,'educationNote':note,'sourceResponseSHA256':j['sourceResponseSHA256'],'semanticObservedContextReviewed':True,'scheduleAllowed':False,'actualCompleteDatesAndClocksKnown':False})
add('1000-9084-00','independentServiceAndUnspecifiedOrientation','30hours institutional volunteer service coordinated individually. First-Friday09:30 orientation mentioned but exact current date/place/end not all printed; no weekly recurring clock.')
for cid in ['1000-9232-00','1000-9236-00']:
 add(cid,'independentServiceMayBeVacation','30hours educational volunteer service may be during vacation or semester; actual placement dates/clock student/institution coordinated. Do not generate weekly class from service-hour total.')
add('1112-1001-00','pedagogicalTopicIntensityNotCalendarBlock','Topic-focused intensive lecture is pedagogical description; no short-term/block teaching dates established by this wording.')
add('1159-2029-00','seaPracticalBlockUndated','Actual maritime practical training2nights3days, actual date/start/end/place not printed. Untimed course remains untimed;15weekly topics do not mean15voyages.')
add('1159-3037-00','winterPracticalBlockUndated','Classroom theory and3nights4days winter ski block coexist. Actual ski dates/hours/place missing; ordinary Monday clock cannot be reused as full ski calendar.')
add('1182-2027-00','selectionPeriodNotInstructionPeriod','Summer selection restricts eligible2026global field-learning program participants; selection season is not actual summer teaching interval. Actual fieldlearning dates/place not printed.')
for cid in ['1214-3006-00','1214-3006-01']:
 add(cid,'vacationPreparationNotInstruction','Students asked to prepare prerequisites during vacation; this is independent prelearning, not vacation teaching dates.')
for section in range(14):
 cid=f'1345-7009-{section:02d}';j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());method=j['header'][0].get('LSN_OPER_MTHD','')
 if section in [0,3,5]:note='3nights4days actual ski block intended but plan retains2017dated theory/orientation or ski dates; do not reuse past dates.'
 elif section==1:note='Ski block described in December2025 despite current2026-2identity; actual current dates/place unresolved.'
 elif section==2:note='3nights4days ski block proposed around lateDecember2026–earlyJanuary2027, explicitly adjustable; no fixed begin/end/date/hours.'
 elif section in [8,9,12]:note='Current2026orientation/theory start dates may be printed, but exact ends and required ski3nights4days period/place remain undecided; partial start facts do not complete calendar.'
 else:note='Actual3nights4days ski block required and date/venue announced later, sometimes wintervacation or endDecember–Januarywindow; do not invent chosen days or ordinary repeated Mondayhours.'
 add(cid,'requiredSkiBlockActualDatesUnresolved',note)
(R/'cnu-reviewed-intensive-contexts-20261008.json').write_text(json.dumps({'reviews':cases,'count':len(cases),'wholeSemanticReviewComplete':False,'actualFixedDurationNotConvertedToInventedDateInterval':True},ensure_ascii=False,indent=2));print('reviewed intensive/service contexts',len(cases))
