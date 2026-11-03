"""Source-semantic shortlist; lab pedagogy and hypothetical fallback are not exceptions."""
import json,re,collections
from pathlib import Path
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parents[1]/'catalog-f'
BASE=OUT.parent/'cnu-ordinary-reservation-v1-20261008'
source=json.loads((BASE/'cnu-unknown-2026-2.ordinary-reservation-research-v1-20261008.json').read_text())
# Actual institutional/native course methods gate first; topic words are not delivery facts.
remote=re.compile(r'비대면\s*(?:수업|강의)|온라인\s*(?:수업|강의)|원격\s*(?:수업|강의)|녹화\s*(?:수업|강의)|동영상\s*(?:수업|강의)|사이버\s*강의|블[렌랜]디드|blended|asynchronous|recorded\s*lecture',re.I)
conditional=re.compile(r'경우|필요[시할]|상황|부득이|유사시|비상|코로나|불가[능피]|시행될\s*경우|전환할\s*수|따라\s*변경|조건',re.I)
delivery_condition=re.compile(r'(?:경우|필요시|부득이|불가능|비상|유사시)[^\n]{0,90}(?:비대면|원격|온라인)|(?:비대면|원격|온라인)[^\n]{0,65}경우|(?:코로나|거리두기)[^\n]{0,90}(?:지속하는\s*경우|단계|상향|변동)|대면[^\n]{0,65}불가능',re.I)
current_foreground=re.compile(r'2026[^\n]{0,35}(?:2학기|2\s*학기)[^\n]{0,45}대면',re.I)
foreground=re.compile(r'대면\s*(?:수업|강의)|강의실\s*(?:출석|수업|강의)|실험실\s*(?:에서|수업)|실습실\s*(?:에서|수업)|in[- ]?person|face[- ]?to[- ]?face',re.I)
allocation=re.compile(r'현장\s*실습|인턴[쉽십]|임상\s*실습|학교현장|개인별\s*(?:배정|시간|일정)|개별\s*(?:배정|시간|일정)|조별\s*(?:시간|일정)|별도\s*(?:시간|일정)|집중\s*(?:이수|수업|강의)|block\s*teaching',re.I)
individual_clock=re.compile(r'(?:개인|개별|조별|각\s*조|각\s*팀|그룹별)[^\n]{0,35}(?:시간|날짜|요일|일정|배정)',re.I)
frequency=re.compile(r'격주|2주\s*마다|짝수\s*주|홀수\s*주|biweekly|half[- ]?semester',re.I)
weekly_cancel=re.compile(r'휴강|수업\s*(?:이\s*)?없|no\s*class|class\s*cancel',re.I)
weekly_remote=re.compile(r'^(?:\d+[. ]*)?(?:비대면|온라인|원격|녹화|동영상|사이버)(?:수업|강의|\s*수업|\s*강의|\s*진행|\s*대체)|(?:수업|강의)[^\n]{0,30}(?:녹화|비대면|온라인|원격)(?:로|으로|\s*진행)|(?:대신|대체)[^\n]{0,20}(?:영상|온라인|원격)',re.I)
rows=[]
for c in source['courses']:
 if c['schedules']:continue
 e=c['sourceEducation'];f=e['originalEducationFields'];cid=e['courseId'];reasons=[]
 if f.get('CLOSE_YN')!='0':reasons.append('CurrentlyClosed')
 if f.get('LSN_TYPE_CD_NM') not in ['이론','실습','이론/실습']:reasons.append('NativeIndividualOrVirtualType')
 if f.get('LSN_METHOD_CD_NM') not in [None,'']:reasons.append('NativeSpecialDeliveryMethod')
 slots=e['actualDisplayedClocks']
 if not slots or any(not s['location'] for s in slots):reasons.append('NativeClockRoomMissing')
 path=OUT/'current-education'/f'{cid}.json'
 if not path.exists():path=SOURCE/'cnu-current-education'/f'{cid}.json'
 p=json.loads(path.read_text()) if path.exists() else None
 methods=[];fallbacks=[];weekly=[];signals=[]
 if not p or not p.get('header'):reasons.append('CompleteCurrentSourceContextReviewNeeded')
 else:
  for h in p['header']:
   if h.get('OPEN_SHTM_CD_NM')!='2학기':reasons.append('SemesterConflict')
   if h.get('LSN_MTHD_SCENE') not in [None,0,'0','']:reasons.append('PublishedFieldTeachingHoursNeedActualAllocation')
   main=str(h.get('LSN_OPER_MTHD',''));alternative=str(h.get('LSN_OPER_MTHD_UNTACT',''));methods.append(main)
   if not foreground.search(main):reasons.append('ExplicitOrdinaryForegroundNeedsReview')
   for line in main.splitlines():
    if remote.search(line) and not conditional.search(line):signals.append(line);reasons.append('MainCurrentSpecialDeliveryStatement')
   if alternative and remote.search(alternative):
    if delivery_condition.search(alternative) or (current_foreground.search(main) and re.search(r'202[0-5][^\n]{0,20}(?:학기|년도)',alternative) and not re.search(r'2026[^\n]{0,20}(?:학기|년도)',alternative)):fallbacks.append(alternative)
    else:reasons.append('AlternativeActualVersusHypotheticalNotYetResolved')
   if re.search(r'(?<!\d)\d{1,2}:\d{2}(?!\d)|(?<!\d)\d{1,2}\s*시(?!간)',main):reasons.append('ExplicitExtraOperatingClockNeedsIndependentReview')
   if frequency.search(main):reasons.append('CurrentAlternateOrShortPeriodNeedsExplicitDates')
   if individual_clock.search(main):reasons.append('ActualGroupOrIndividualTimeNeedsIndependentReview')
   if allocation.search(main):signals.append(main);reasons.append('ActualIndividualIntensiveOrFieldAllocationSignal')
  for w in p['weeks']:
   if str(w.get('CLS_METHOD_FIELD',0))=='1':reasons.append('PublishedFieldWeekNeedsActualAllocation')
   for key in ['MAJ_LRN_CTNT','ETC_CTNT','PRJT']:
    text=str(w.get(key,''))
    if re.search(r'(?<!\d)\d{1,2}:\d{2}(?!\d)|(?<!\d)\d{1,2}\s*시(?!간)',text):reasons.append('ExplicitWeeklyTimeNeedsAssignmentVersusTeachingReview')
    if frequency.search(text):reasons.append('CurrentAlternateOrShortPeriodNeedsExplicitDates')
    if weekly_cancel.search(text) or individual_clock.search(text):reasons.append('KnownWeeklyCancellationOrIndividualClockNeedsIndependentReview')
    if weekly_remote.search(text) or allocation.search(text):weekly.append({'week':w.get('WKORD'),'field':key,'text':text});reasons.append('ExplicitWeeklySpecialInstructionNeedsReview')
 rows.append({'sourceId':c['sourceId'],'courseId':cid,'courseName':c['courseName'],'nativeCourseType':f.get('LSN_TYPE_CD_NM'),'sourceSchedule':c['sourceSchedule'],'sourceClassroom':c['sourceClassroom'],'screenReasons':sorted(set(reasons)),'shortlistOnly':not reasons,'foregroundEducationalStatements':methods,'conditionalAlternativeStatements':fallbacks,'actualWeeklySignals':weekly,'currentSourceRecoveryRequired':True})
report={'completionClaim':False,'productionEdited':False,'sdkUsed':False,'shortlist':sum(r['shortlistOnly'] for r in rows),'reasonCounts':dict(collections.Counter(x for r in rows for x in r['screenReasons'])),'decisions':rows};OUT.joinpath('source-semantic-screen.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(report['shortlist'],report['reasonCounts'])
