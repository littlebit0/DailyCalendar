# coding:utf-8
import copy,hashlib,json
from pathlib import Path
ROOT=Path.cwd();D=Path(__file__).parent;F=ROOT/'work/university-research/catalog-f/mju'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,v):(D/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
paths={'humanities':F/'natural-reference-v3-fixture-derivative-20261009/baseline-humanities.json','natural':F/'current-natural-reference-v3-20261009/mju-natural-2026-2.natural-reference-v3.json','unknown':F/'natural-reference-v3-fixture-derivative-20261009/baseline-unknown.json'}
prior={k:read(p) for k,p in paths.items()};base=[c for d in prior.values() for c in d['courses']]
assert len(base)==209
lookup={c.get('sourceEducation',{}).get('nativeLectureNumber'):c for c in base}
closedpath=F/'mju-current-final-closure-education-20261008.json';closed=read(closedpath)['closedCourses']
elecpath=F/'current-electronics-increase-education-v4-20261009/current-electronics-printed-education.json';iepath=F/'current-ie-specific-course-education-v4-20261009/current-one-course-education.json'
sources=[('전자공학전공',elecpath),('산업경영공학과',iepath)];new=[];proofs=[]
for department,p in sources:
 source=read(p)
 assert source.get('academicYear',2026)==2026 and source.get('semester','2')=='2'
 for row in source['educationRows']:
  n=row['nativeLectureNumber'];assert len(n)==4 and n.isdigit() and n not in lookup
  assert not any(c['nativeLectureNumber']==n for c in closed)
  restriction=source.get('nativeRestrictionStatements',source.get('nativeStatements',[]))
  note='2026학년도 2학기 공식 공개 안내에 인쇄된 강좌번호 참조입니다. 과목코드·분반·요일·수업시각·강의실·개별 캠퍼스 미게시; 신규 예약은 보류합니다. 강좌번호를 과목코드나 분반으로 변환하지 않았습니다. 전체 학부 개설목록·최신 전체 폐강 확인은 미완료입니다. '
  if row.get('scope'):note+='원문 해당 행 범위: '+row['scope']+'. '
  if department=='전자공학전공':note+='수기 증원 제한은 증원 신청에 관한 조건이며 전체 수강자격으로 일반화하지 않습니다. 증원불가는 폐강이 아닙니다. '
  note+='학교 원문 조건: '+' / '.join(restriction)
  c={'sourceId':f'mju/unknown/2026-2/{n}','referenceKind':'nativeLectureNumber','campus':'unknown','academicYear':2026,'semester':'2','courseCode':'','courseName':row['courseName'],'section':'','professor':row['professor'],'classification':'','departmentClassifications':{},'credits':None,'departmentCredits':{},'departments':[department],'departmentRemarks':{department:note},'sourceSchedule':'','sourceClassroom':'','scheduleStatus':'unrecognized','schedules':[],'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':n,'nativeCourseCodePublished':False,'nativeSectionPublished':False,'sourceCampusIndividuallyPrinted':False,'nativePublicCells':copy.deepcopy(row),'nativeRestrictionStatements':copy.deepcopy(restriction),'sourceUrl':source['sourceUrl'],'sourceEducationReceiptSHA256':sha(p),'sourceTermStatement':source.get('nativeAcademicHeading',source.get('nativeTermStatement')),'closed':False,'noPrintedClosureMatch':True,'wholeLatestClosureConfirmed':False,'actualOperatingMeetingsConfirmed':False,'operatingReviewComplete':False}}
  new.append(c);proofs.append({'sourceId':c['sourceId'],'sourceFile':str(p.relative_to(ROOT)),'nativeRow':copy.deepcopy(row),'nativeRegistrationReferencesDisjointFromPrior209':True,'canonicalCodeSectionNotInvented':True,'campusNotPrintedRemainsUnknown':True,'newAppointments':0})
assert len(new)==11
candidate=copy.deepcopy(prior['unknown']);candidate['courses']+=new;candidate['researchOnly']=True;candidate['productionIntegrationEnabled']=False;candidate['completionClaim']=False;candidate['wholeSchoolCourseCoverageComplete']=False
write('mju-unknown-2026-2.electronics-ie-reference-v4.json',candidate)
combined=prior['humanities']['courses']+prior['natural']['courses']+candidate['courses'];assert len(combined)==220 and len({c['sourceId'] for c in combined})==220
byid={c['sourceId']:c for c in combined}
for c in base:assert byid[c['sourceId']]==c
write('independent-native-reference-preservation-proof.json',{'sourceInputs':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in list(paths.values())+[closedpath,elecpath,iepath]],'priorDatasetPaths':{k:str(p.relative_to(ROOT)) for k,p in paths.items()},'prior209WholeObjectsExact':True,'newMetadataReferences':11,'combinedObjects':220,'newAppointments':0,'priorScheduledCourses':7,'priorAppointments':172,'newNativeClosureMatches':0,'proofs':proofs,'explicitlyExcludedUnconfirmedCurrentTermProfessorChangeReferences':['0536','0537'],'SDKExecuted':False,'completionClaim':False})
print('PASS structural whole-preservation209;11new unknown-campus references;220total;0new appointments')
