"""Whole3888 education rows remain searchable; only3 actual-dated courses may schedule."""
import json,hashlib,collections
from pathlib import Path
R=Path(__file__).resolve().parent
rows=json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())
clocks={c['courseId']:c for c in json.loads((R/'cnu-current-clock-projection.json').read_text())}
review={c['courseId']:c for c in json.loads((R/'cnu-current-review-status-index.json').read_text())['rows']}
verified={}
for campus in ['daedeok','unknown']:
 d=json.loads((R/f'cnu-{campus}-2026-2.three-course-checkpoint.json').read_text())
 for c in d['courses']:verified[c['sourceEducation']['courseId']]=c
bycampus={'daedeok':[],'unknown':[]};counts=collections.Counter()
EDUCATION_FIELDS=['CPTN_DIV_CD_FNM','CURI_CPTN_DIV_NM','PNT_TMCNT','TRGT_SHYR','TLSN_REST_INFO_CD_NM','TLSN_ANNM','LSN_TYPE_CD_NM','LSN_METHOD_CD_NM','CYBER_LT_TYPE_CD_NM','TCHR_FLD_CD_NM','TCHR_FLD_CD_NM2','ENG_SBJT_NM','ABEEK_CPTN_DIV_CD_NM','ABEEK_TMCNT','OBJ_CORS_CD_NM','CULT_FLD_CD_NM','CURI_CORS_YR','LSN_TM_CD','OPEN_YR','CLOSE_YN','CNCL_LT_YN','CNCL_LT_DT']
for row in rows:
 cid=row['COURSE_NO'];department=row['OPEN_SUST_MJ_CD_NM'];credit=float(row['PNT_TMCNT'].split('/')[0]);classification=row['CPTN_DIV_CD_FNM']
 if cid in verified:
  course=verified[cid];status='scheduled'
 else:
  closed=str(row['CLOSE_YN'])=='1';untimed=not (row['TMTBL_INFO'] or '').strip();status='closedBlocked' if closed else 'untimed' if untimed else 'activeBlocked'
  displayStatus='unscheduled' if status=='untimed' else 'unrecognized'
  reason='현재 폐강된 강좌입니다.' if closed else '공식 수강편람에 고정 수업 시각이 표시되어 있지 않습니다.' if untimed else '수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
  originalNotes=[row.get('TLSN_ANNM') or '',row.get('TLSN_REST_INFO_CD_NM') or '']
  notes='\n'.join(n for n in originalNotes+[reason] if n)
  actualClock=clocks[cid]['actualClockMeetings'];room=' / '.join(dict.fromkeys(m['location'] for m in actualClock if m['location']))
  course={
   'sourceId':f'cnu/unknown/2026-2/{cid}',
   'campus':'unknown','academicYear':2026,'semester':'2',
   'courseCode':row['OPEN_SBJT_NO'],'courseName':row['SBJT_NM'],'section':row['OPEN_DCLSS'],
   'professor':row['LT_STAFF_NM'] or '',
   'classification':classification,'departmentClassifications':{department:classification},
   'credits':credit,'departmentCredits':{department:credit},'departments':[department],
   'departmentRemarks':{department:notes},
   'sourceSchedule':row['TMTBL_INFO'] or '','sourceClassroom':room,
   'scheduleStatus':displayStatus,'schedules':[],
   'sourceEducation':{
    'courseId':cid,'originalEducationFields':{k:row.get(k) for k in EDUCATION_FIELDS},
    'actualDisplayedClocks':actualClock,
    'individualReviewStatus':review[cid]['status'],
    'registrationStatus':status,'derivedBlockingExplanation':reason,
    'campusProof':'No confirmed full-building campus assignment; original room abbreviation preserved',
    'wholeSourceClosureFlag':row['CLOSE_YN'],
    'datesOrClockInvented':False,
   },
  }
 counts[status]+=1;bycampus[course['campus']].append(course)
files=[]
for campus,courses in bycampus.items():
 data={
  'schemaVersion':2,'universityId':'cnu','campus':campus,
  'campusName':'대덕캠퍼스' if campus=='daedeok' else '캠퍼스 미확인',
  'academicYear':2026,'semester':'2','publishedDate':'2026-10-08',
  'sourceUrl':'https://cnuit.cnu.ac.kr/checkMenu.jsp?p0=M69r16057e79Y231',
  'courses':courses,'wholeCurrentMetadataRetained':True,'wholeSemanticReviewComplete':False,
  'wholeUniversitySupportComplete':False,
 }
 path=R/f'cnu-{campus}-2026-2.whole-checkpoint.json';path.write_text(json.dumps(data,ensure_ascii=False,indent=2));files.append(path)
assert sum(counts.values())==3888 and counts['scheduled']==3 and counts['untimed']==635 and counts['closedBlocked']==142
out={
 'wholeCurrentCourses':3888,'currentActive':3746,'currentClosed':142,
 'registrationStates':dict(counts),'actualPrintedScheduledMeetings':60,
 'campusCounts':{c:len(v) for c,v in bycampus.items()},
 'publicNameRefreshOccurredAfterWholePlanCollectionCompleted':True,
 'instructorNameReadWasOneNormalWholeCatalogRequest':True,
 'unverifiedActiveOrClosedCoursesNotSilentlyRemoved':True,
 'unverifiedCoursesHaveNoSchedulableMeetings':True,
 'nativeClassificationRestrictionsRemarksAndDisplayedRoomsPreserved':True,
 'wholeSchoolSupportComplete':False,
 'hashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files},
}
(R/'cnu-whole-registration-checkpoint-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
