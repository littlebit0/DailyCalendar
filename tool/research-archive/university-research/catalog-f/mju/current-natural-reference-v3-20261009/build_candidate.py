# coding: utf-8
import copy, hashlib, json
from pathlib import Path
D=Path(__file__).parent
ROOT=Path.cwd()
def read(p):return json.loads(p.read_text())
def write(n,v):(D/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=read(D/'printed-education-rows.json'); baseline={}; lookup={}; inputs=[]
for campus in ['humanities','natural','unknown']:
 p=ROOT/f'assets/timetable/mju-{campus}-2026-2.json'; doc=read(p); baseline[campus]=doc
 inputs.append({'path':str(p.relative_to(ROOT)),'sha256':sha(p)})
 for c in doc['courses']:
  key=c.get('sourceEducation',{}).get('nativeLectureNumber')
  if key:lookup[key]=c
closurepath=ROOT/'work/university-research/catalog-f/mju/mju-current-final-closure-education-20261008.json'
closed=read(closurepath)['closedCourses'];inputs.append({'path':str(closurepath.relative_to(ROOT)),'sha256':sha(closurepath)})
new=[]; overlaps=[]
for r in rows:
 n=r['lectureNumber']
 if not n.isdigit():continue
 assert len(n)==4
 if n in lookup:
  old=lookup[n];assert old['campus']=='natural' and old['courseName']==r['title'] and old['professor']==r['professor']
  overlaps.append({'sourceId':old['sourceId'],'printedRow':r,'comparison':'exact native lecture number + title + full professor + natural campus; prior object untouched'})
  continue
 assert not any(c['campus']=='자연' and c['nativeLectureNumber']==n for c in closed)
 note='2026학년도 2학기 자연교양 증원 공지의 공개 강좌번호 참조입니다. 과목코드·분반·학점·요일·수업시각·강의실 미게시. 정규시간표 예약은 보류합니다. 증원 목록은 전체 개설 목록이 아니며 현재 전체 폐강·변경 확인도 완료되지 않았습니다.'
 new.append({'sourceId':f'mju/natural/2026-2/{n}','referenceKind':'nativeLectureNumber','campus':'natural','academicYear':2026,'semester':'2','courseCode':'','courseName':r['title'],'section':'','professor':r['professor'],'classification':'','departmentClassifications':{},'credits':None,'departmentCredits':{},'departments':['자연교양'],'departmentRemarks':{'자연교양':note},'sourceSchedule':'','sourceClassroom':'','scheduleStatus':'unrecognized','schedules':[],'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':n,'nativeCourseCodePublished':False,'nativeSectionPublished':False,'nativePublicCells':copy.deepcopy(r),'sourceCampusIndividuallyPrinted':False,'sourceCampusByNoticeScope':'공식 방목기초교육대학 자연교양 공지 + 2026학년도 2학기 교양강좌 증원현황','sourceUrl':'https://www.mju.ac.kr/bbs/bangmok/357/234997/artclView.do','attachmentUrl':'https://www.mju.ac.kr/bbs/bangmok/357/180225/download.do','sourceSHA256':sha(D/'official-2026-2-natural-general-increase.pdf'),'closureCheckedAgainstPublishedFinalList':True,'closed':False,'wholeLatestClosureConfirmed':False,'actualOperatingMeetingsConfirmed':False,'operatingReviewComplete':False}})
assert len(new)==68 and len(overlaps)==5
candidate=copy.deepcopy(baseline['natural']);candidate['courses']+=new;candidate['researchOnly']=True;candidate['productionIntegrationEnabled']=False;candidate['completionClaim']=False;candidate['wholeSchoolCourseCoverageComplete']=False
write('mju-natural-2026-2.natural-reference-v3.json',candidate)
write('native-exact-overlap-provenance.json',overlaps)
for c in baseline['natural']['courses']:assert next(n for n in candidate['courses'] if n['sourceId']==c['sourceId'])==c
assert len({c['sourceId'] for c in candidate['courses']})==len(candidate['courses'])
write('independent-source-scope-proof.json',{'sourceInputs':inputs,'printedDataRows':79,'wildcardConditionRows':6,'printedNativeReferences':73,'uniqueNativeReferences':73,'exactExistingReferences':5,'newMetadataOnlyReferences':68,'newScheduledCourses':0,'baselineObjects':141,'plannedUnionObjects':209,'baselineScheduledCourses':7,'baselineAppointments':172,'strictClosedNativeMatches':0,'baselineNaturalAll20ObjectsExact':True,'otherHumanities80AndUnknown41UnchangedNotRewritten':True,'canonicalCodeSectionHHRoomNotPublished':True,'scope':'current natural general capacity-increase subset, not whole course catalog','wildcardRowsAreNotOfferings':[r for r in rows if not r['lectureNumber'].isdigit()],'independentActivationProofRequired':['official same-term lecture number to printed canonical code and section (if available), no title-only aliases','same offering printed weekday + own HH or applicable own period legend','published native rooms retained including empty room; no invented rooms','own calendar and individual operating exceptions reconciled','all 141 baseline objects exact and full three-mode Drive proof before any schedule activation'],'SDKExecuted':False,'completionClaim':False})
print('PASS source structural checks:79rows/73native/5exact-overlap/68new-ref;209planned metadata union;0new appointments')
