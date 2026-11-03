"""Current visible undergraduate catalog metadata; no inferred weekly clocks/dates."""
import collections,hashlib,json,pathlib,re
D=pathlib.Path(__file__).parent/'jbnu-current-20261008'
def write(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
bycampus=collections.defaultdict(list);names={'전주':'jeonju','익산':'iksan','남원':'namwon','고창':'gochang','새만금':'saemangeum'}
for t in [1,2,3,4,7]:
 src=json.loads((D/f'current-public-type{t}-education.json').read_text())
 for e in src['rows']:
  code=e['STDTR_NO'];sec=str(e['DVCLS_NO']);campuses=sorted(set(re.findall('(전주|익산|고창|남원|새만금):',e['DONG_RMNM_CN'] or '')));campus=names[campuses[0]] if len(campuses)==1 else 'unknown'
  cat=e['CMCRS_DIVCDNM'] or '';dept=e['MNG_SCSBJT_CDNM'] or '';credit=e['ESTBL_PNT'];group='전공' if t==1 else '교양' if t==2 else '교직' if t==3 else '일반선택' if t==7 else ''
  remark='2026-10-08 공식 개설강좌보기 공개 조회기간Y에서 확인한 학부 강좌 메타데이터입니다. 전체 개별 실제수업기간·clock·실시간변경 완전성은 미확인. 원문A/B표시를 임의시각으로 변환하지 않아 수업일정 미생성. 캠퍼스는 원문강의실 앞 명칭만 사용했습니다. '+ '; '.join(k+': '+str(e[k]) for k in ['LESSN_HR_DIVCDNM','LESSN_OPER_DRC_CN','SCSBJT_SCYR_NTC_CN','ATNLC_TRGT_DIVCDNM','FTF_UNTACT_DIVCDNM','LCTR_LANG_DIVCDNM','RLM_DIVCDNM','CULT_RLM_DIVCDNM','PRVT_DIVCDNM','OPNLT_DIVCDNM','CERT_DIVCDNM'] if e.get(k))
  bycampus[campus].append({'sourceId':f'jbnu-2026-2-{code}-{sec}','referenceKind':'공개 과목번호','canonicalSubjectCodePublished':True,'nativeSectionPublished':True,'academicYear':2026,'semester':'2','campus':campus,'nativeCampusAliases':campuses,'courseCode':code,'section':sec,'courseName':e['SBJCT_NM'],'professor':e['STAFFNM'] or '', 'credits':credit,'classification':cat,'classificationGroup':group,'departments':[dept] if dept else [],'departmentCredits':{dept:credit} if dept and credit is not None else {},'departmentClassifications':{dept:cat} if dept else {},'departmentRemarks':{dept:remark} if dept else {},'remarks':remark,'sourceSchedule':e['DOW_HR_CN'] or '', 'sourceClassroom':e['DONG_RMNM_CN'] or '', 'scheduleStatus':'unrecognized','schedules':[],'publicEducationRow':e,'publicSourceType':t,'publishedIndividualOperatingPeriodVerified':False})
files=[]
for campus,cs in sorted(bycampus.items()):
 f=f'jbnu-{campus}-2026-2.current-metadata-20261008.json';write(f,{'schemaVersion':2,'universityId':'jbnu','campus':campus,'campusName':next((k+'캠퍼스' for k,v in names.items() if v==campus),'캠퍼스 미확인'),'academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://jump.jbnu.ac.kr/link?div=sucrPlan','courses':cs});files.append({'file':f,'campus':campus,'classes':len(cs),'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()})
old=json.loads(pathlib.Path('work/university-research/catalog-f/jbnu-course-rows.json').read_text());oldids={(r['STDTR_NO'],str(r['DVCLS_NO'])) for r in old};ids={(r['courseCode'],r['section']) for cs in bycampus.values() for r in cs}
write('whole-metadata-audit.json',{'completionClaim':False,'candidates':files,'currentClasses':sum(len(cs) for cs in bycampus.values()),'uniqueNativeIdentities':len(ids),'priorAbsentNow':sorted(oldids-ids),'newNow':sorted(ids-oldids),'campusAssignments':'exact published DONG_RMNM_CN campus prefix only','scheduledClasses':0,'nativeMetadataAndMedicalDocumentOverlap':'Do not register both as distinct actual offerings without an explicit cross-source identity join; medicine document has no official codes/sections.','productionChanged':False})
print([(p['campus'],p['classes']) for p in files])
