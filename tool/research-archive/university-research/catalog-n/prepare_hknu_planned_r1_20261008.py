"""Compose dated public planned classes, preserving current educational conditions."""
import json,pathlib,re,copy,datetime as dt,hashlib,sys,importlib.util,collections
from urllib.parse import quote
from openpyxl import load_workbook
R=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('hknu_import',R.parents[2]/'tool/timetable/import_hknu.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
initial=json.loads((R/'hknu-2026-2-prepared-candidate.json').read_text())['courses']
current=json.loads((R/'hknu-current-education-identity-crosswalk-20261008.json').read_text())['rows']
main=[r for r in current if r['actualCampusField']]

def norm(x):return re.sub(r'\s+','',str(x or ''))
def key(c):return (c['campus'],c['courseCode'],c['section'],norm(c['departments'][0]))
def subjectkey(f):return (norm(f['개설학과']),norm(f['과목명']))
raw_original={}
for campus in ['anseong','pyeongtaek']:
 w=load_workbook(R/f'hknu-2026-2-{campus}.xlsx',data_only=True,read_only=True);s=w.worksheets[0];headers=[norm(c.value) for c in s[3]]
 for row in s.iter_rows(min_row=4,values_only=True):
  if row[0] is None:continue
  f=dict(zip(headers,row));raw_original[(campus,str(f['과목코드']),f['분반'],norm(f['개설전공'] or f['개設学部'] if '개設学部' in f else f['개설전공'] or f['개설학부']))]=f
by={key(c):copy.deepcopy(c) for c in initial};old_by_id={c['sourceId']:c for c in initial}
for c in by.values():
 c['metadata']={'initialPublicEducationalFields':raw_original[key(c)],'initialActualCodePublication':'2026-07-14','actualAttendanceConfirmed':False,'planningAuthority':'current published regular timetable, not attendance confirmation'}
anchors=collections.defaultdict(list)
for r in main:
 if r['directOriginalCampusDepartmentTitleSectionMatches']:
  m=r['directOriginalCampusDepartmentTitleSectionMatches'][0];anchors[m['actualCode']].append(r)
new_code_proofs=[]
for r in main:
 f=r['actualEducationalFields'];matches=r['directOriginalCampusDepartmentTitleSectionMatches']
 if matches:
  assert len(matches)==1;m=matches[0];k=(m['actualCampus'],m['actualCode'],f['분반'],norm(m['actualOpeningDepartment']));c=by[k]
 else:
  codes=r['publishedSubjectCodeSameTitleDepartmentAcrossOtherSections'];assert len(codes)==1
  code=codes[0];assert anchors[code]
  refs=[a for a in anchors[code] if subjectkey(a['actualEducationalFields'])==subjectkey(f) and a['actualEducationalFields']['학점']==f['학점']];assert refs
  anchor=refs[0]['directOriginalCampusDepartmentTitleSectionMatches'][0]
  old=by[(anchor['actualCampus'],code,refs[0]['actualEducationalFields']['분반'],norm(anchor['actualOpeningDepartment']))]
  c=copy.deepcopy(old);c['section']=f['분반'];c['metadata']={'actualAttendanceConfirmed':False,'newPublishedNativeSection':True,'initialActualSubjectCode':code,'currentSubjectIdentityAnchors':[{'sourceRow':a['sourceRow'],'actualCode':code,'publishedSection':a['actualEducationalFields']['분반'],'publishedDepartment':a['actualEducationalFields']['개설학과'],'publishedCredits':a['actualEducationalFields']['학점']} for a in refs],'codeJoinedFromActualSubjectPublicationNotInvented':True};k=(r['actualCampusField'],code,f['분반'],norm(f['개설학과']));assert k not in by;by[k]=c;new_code_proofs.append({'courseCode':code,'section':f['분반'],'currentSourceRow':r['sourceRow'],'currentAnchorSections':[a['actualEducationalFields']['분반'] for a in refs]})
 c['professor']=str(f['교수명'] or '');c['credits']=f['학점'];c['sourceSchedule']=str(f['시간표'] or '')
 room=' / '.join(dict.fromkeys(str(f[n]) for n in ['강의실','실습강의실'] if f.get(n)))
 c['sourceClassroom']=room;slots,reason=mod.clocks(c['sourceSchedule'],room)
 c['schedules']=slots;c['scheduleStatus']='scheduled' if slots else 'unrecognized'
 c['metadata']['currentGeneralPublication']={'sourceDate':'2026-08-24','sourceRow':r['sourceRow'],'sourceSheet':r['sourceSheet'],'actualEducationalFields':f,'redBackgroundGeneralStudentRestriction':r['actualRedBackgroundGeneralStudentRestriction'],'sourceRemoteHeaderStillSaysReviewPending':True}
 dept=c['departments'][0];notes=c['departmentRemarks'][dept]
 notes+='\n현재8/24교양표: '+str(f.get('비고') or '비고 미게시')
 if r['actualRedBackgroundGeneralStudentRestriction']:notes+='\n공식 빨간배경 분반: 일반 재학생 수강 불가.'
 notes+='\n원격 여부: '+str(f.get('원격여부') or '미게시')+' (학교 표 머리말의 심의 미완료 경계 유지).'
 if f.get('원격여부')=='Y':c['schedules']=[];c['scheduleStatus']='unscheduled';notes+='\n원격수업의 실제 실시간 회의 미확인. 학교 원격지침의 동영상·학습활동과 공시 교시를 구분하여 고정 회의 미생성.'
 elif f.get('원격여부')=='혼합':
  text=str(f.get('비고') or '');match=re.search(r'(\([월화수목금토일]\)\s*\d+(?:\.5)?~\d+(?:\.5)?)\s*오프라인',text);assert match
  offline,why=mod.clocks(match[1],room)
  for slot in offline:slot['deliveryMode']='inPerson'
  c['schedules']=offline;c['scheduleStatus']='scheduled' if offline else 'unrecognized';c['metadata']['publishedMixedOfflineSchedule']=match[1];notes+='\n혼합수업의 원문 오프라인 교시만 회의 반영. 온라인 교시는 실시간임을 추정하지 않으며 원문으로 보존.'
 c['departmentRemarks'][dept]=notes
# Current safety cells use actual merged ranges, weekdays and source room literals.
grid=json.loads((R/'hknu-current-safety-merged-education-grid-20261008.json').read_text())['blocks'];group=collections.defaultdict(list)
for block in grid:
 assert len(block['originalIdentityCandidates'])==1;group[block['originalIdentityCandidates'][0]].append(block)
for old_id,blocks in group.items():
 c=by[key(old_by_id[old_id])];slots=[]
 for block in blocks:
  first,last=block['nativeFirstPeriod'],block['nativeLastPeriod'];clock,why=mod.clocks('('+mod.DAYS[block['nativeWeekday']-1]+') '+str(first)+'~'+str(last),block['actualPublishedRoomLiteral'])
  # Numeric spreadsheet endpoints normalize trailing .0 to the same actual period.
  if not clock:clock,why=mod.clocks('('+mod.DAYS[block['nativeWeekday']-1]+') '+f'{first:g}~{last:g}',block['actualPublishedRoomLiteral'])
  assert clock,(old_id,why);slots+=clock
 professors=list(dict.fromkeys(b['actualPublishedProfessor'] for b in blocks if b['actualPublishedProfessor']))
 assert len(professors)<=1
 if professors:c['professor']=professors[0]
 c['schedules']=slots;c['scheduleStatus']='scheduled';c['metadata']['currentSafetyMergedEducationalCells']=blocks
 c['sourceClassroom']=' / '.join(dict.fromkeys(b['actualPublishedRoomLiteral'] for b in blocks if b['actualPublishedRoomLiteral']))
 c['departmentRemarks'][c['departments'][0]]+='\n현재7/22안전공학 표의 실제 병합셀 시각·교수·강의실 반영. 단순명칭으로 산업의료원을 현장실습과 동일하게 취급하지 않음.'
# Exact published opening-major/title/section uniquely identifies known initial classes.
closures=json.loads((R/'hknu-closure34-name-only-candidates-not-applied.json').read_text())['rows'];closed=[]
for row in closures:
 hits=[c for c in by.values() if norm(c['departments'][0])==norm(row['publishedDepartment']) and norm(c['courseName'])==norm(row['publishedName']) and c['section']==row['publishedSection']]
 assert len(hits)==1; c=hits[0];c['schedules']=[];c['scheduleStatus']='unrecognized';c['metadata']['currentFinalPublishedCancellation']={'date':'2026-09-10','openingDepartment':row['publishedDepartment'],'publishedTitle':row['publishedName'],'publishedSection':row['publishedSection'],'actualInitialCodeLinked':c['courseCode'],'codeNotPrintedInClosureFile':True};c['departmentRemarks'][c['departments'][0]]+='\n공식9/10최종폐강: 현재 동일개설학과·제목·분반의 실제코드 연계 강좌. 시간표 추가 대상 제외.';closed.append(key(c))
# Official weekday-specific15th class endpoints; Friday/Saturday designated replacements.
ends={1:'2026-12-21',2:'2026-12-08',3:'2026-12-09',4:'2026-12-17',5:'2026-12-18',6:'2026-12-19',7:'2026-12-21'}
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
extra={5:'2026-12-15',6:'2026-12-16'}
for c in by.values():
 weekly=copy.deepcopy(c['schedules']);dated=[]
 for slot in weekly:
  day=dt.date(2026,9,1);end=dt.date.fromisoformat(ends[slot['weekday']])
  while day<=end:
   if day.isoweekday()==slot['weekday'] and day.isoformat() not in holidays:dated.append(dict(slot,date=day.isoformat()))
   day+=dt.timedelta(days=1)
  if slot['weekday'] in extra:
   date=extra[slot['weekday']];dated.append(dict(slot,weekday=dt.date.fromisoformat(date).isoweekday(),date=date))
 c['schedules']=dated;c['period']={'startDate':'2026-09-01','endDate':'2026-12-21'}
 c['metadata']['publishedWeeklyMeetingsUsedForPlan']=weekly;c['metadata']['weekdayTeachingEndpoints']=ends;c['metadata']['officialMakeupAuthority']='https://www.hknu.ac.kr/bbs/hksystem/243/98107/artclView.do';c['metadata']['plannedNotActualIndividualExamClock']=True
 c['sourceId']=f"hknu/{c['campus']}/2026/2/{c['courseCode']}/{c['section']}/{quote(norm(c['departments'][0]),safe='')}"
 c['departmentRemarks'][c['departments'][0]]+='\n학교 현재15주 수업·휴업·지정보강 기준의 공시예정시간표. 원금요일9/25수업은12/15, 원토요일9/26수업은12/16 지정보강계획으로 반영. 개별 시험시각·실제 출석·교수별 변경확정 주장이 아님.'
assert len(by)==1493 and len(closed)==34 and len(new_code_proofs)==6
files=[]
for campus in ['anseong','pyeongtaek']:
 courses=[c for c in by.values() if c['campus']==campus]
 d={'schemaVersion':2,'universityId':'hknu','campus':campus,'academicYear':2026,'semester':'2','publishedDate':'2026-09-10','sourceUrl':'https://www.hknu.ac.kr/bbs/hkhuman/620/97264/artclView.do','researchOnly':True,'completionClaim':False,'sourceScope':'current public whole July offering with verified published Aug/Sept subset changes','courses':courses}
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r1.json';path=R/name;assert not path.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();path.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(courses),'scheduledCount':sum(bool(c['schedules']) for c in courses),'dateCount':sum(len(c['schedules']) for c in courses)})
manifest={'researchOnly':True,'completionClaim':False,'files':files,'totalCourseCount':1493,'totalScheduledCount':sum(x['scheduledCount'] for x in files),'totalDateCount':sum(x['dateCount'] for x in files),'newNativeSectionsActualSubjectCodeCrossDocumentAnchors':new_code_proofs,'currentFinalClosedIdentities':34,'sourceModeUnknownNotForcedInPerson':True,'sourceExplicitMixedOfflinePartialOnly':19,'wholeOperatingSupportComplete':False,'remaining':['other department later public changes not completely audited','night fractional or day-night boundary clocks','other field/internship actual periods','counseling individual dates','remote full3 no realtime attendance','mixed online portion recorded only'],'sourceRecheck':'hknu-current-whole-and-subset-source-recheck-20261008.json'}
(R/'hknu-planned-audited-20261008-r1-sha-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(files)
