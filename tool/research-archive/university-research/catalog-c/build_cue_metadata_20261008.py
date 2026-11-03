import json,hashlib,zipfile
from pathlib import Path
p=Path('work/university-research/catalog-c/cue-current-20261008');p.mkdir(exist_ok=True)
g=Path('work/university-research/catalog-g')
rows=json.loads((g/'cue2026-2-final-sections.json').read_text());overlay=json.loads((g/'cue2026-2-teacher-overlay-audit.json').read_text())
matches={(x['sourceIdentity']['code'],x['sourceIdentity']['section'],x['sourceIdentity']['grade']):x for x in overlay['matched']}
conflicts={(x['raw']['교과목 코드'],x['raw']['분반'],x['raw']['학년']):x for x in overlay['issues']}
courses=[]
for r in rows:
 key=(r['교과목 코드'],r['분반'],r['학년']);match=matches.get(key);conflict=conflicts.get(key)
 professor=match['change']['teacher'] if match else r['교수명']
 group='교직' if r['교과과정']=='교직' else ('교양' if r['이수구분'].startswith('교양') else '')
 c={'sourceId':'cue-2026-2-'+'-'.join(key),'academicYear':2026,'semester':'2','campus':'unknown','courseCode':r['교과목 코드'],'section':r['분반'],'courseName':r['과목명'],'professor':professor,'credits':r['학점'],'classification':r['이수구분'],'classificationGroup':group,'nativeCurriculum':r['교과과정'],'departments':[r['학년']],'departmentCredits':{r['학년']:r['학점']},'departmentClassifications':{},'departmentRemarks':{},'remarks':'진주교대 공식 2026-2 최종 수강신청 공개 자료입니다. 원문 코드·분반·학년을 보존하며 동일 코드·분반이어도 학년이 다르면 합치지 않았습니다. 강사변경표 42개 일치 항목만 적용; 4개 시간충돌은 원문 메타와 함께 별도 보류합니다. 현재 강의 교시의 실제 시각 미확인(1학기 시험 시각으로 대체하지 않음), 실습 보충강의 개별 계획·폐강 완전성 및 물리 캠퍼스 미확인으로 일정 저장을 보류합니다.','sourceSchedule':r['강의시간'],'sourceClassroom':r['강의실'],'scheduleStatus':'unrecognized','scheduleHoldReason':'현재 강의 교시 clock/실습 보충강의 날짜 미확인'+('; 강사변경표 교시충돌' if conflict else ''),'schedules':[],'publicEducationRow':r,'matchedTeacherChange':match,'conflictingTeacherChange':conflict}
 courses.append(c)
raw={'schemaVersion':2,'universityId':'cue','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-06','sourceUrl':'https://www.cue.ac.kr/kor/CMS/Board/Board.do?mCode=MN177&mode=view&board_seq=85097','courses':courses}
f='cue-unknown-2026-2.metadata-only-20261008.json';(p/f).write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n')
(p/'native-educational-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(p/'teacher-educational-overlay.json').write_text(json.dumps(overlay,ensure_ascii=False,indent=2)+'\n')
z=zipfile.ZipFile('/private/tmp/cue2026-2-fresh.zip');old=zipfile.ZipFile(g/'cue2026-2-final-catalog.zip')
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'nativeClasses':493,'nativeCodeSectionUnique':489,'nativeCodeSectionGradeUnique':493,'matchedTeachers':42,'teacherClockConflicts':4,'scheduledClasses':0,'completionClaim':False,'freshWholeFiveFilesByteIdentical':all(z.read(n)==old.read(n) for n in z.namelist() if not n.endswith('/')),'freshTeacherPDFByteIdentical':Path('/private/tmp/cue-teacher-change-fresh.pdf').read_bytes()==(g/'cue2026-2-change0831.pdf').read_bytes(),'currentGuideSource':'https://archive.cue.ac.kr/archive/record/view?iidx=2249&itemCode=0002','currentGuidePDF':'https://archive.cue.ac.kr/archive/content-file/pdf-stream-view?cfidx=11493','currentGuideSHA':hashlib.sha256(Path('/private/tmp/cue-student-guide2026.pdf').read_bytes()).hexdigest(),'guideVisualPagesReviewed':[3,15,26,27,28,29],'clockNotFoundInCurrentGuideReviewedAcademicSection':True,'rulePublicListFailure':['GET500','publishedPOST405'],'currentPracticePolicy':'교육실습기간에는 보충강의 계획을 수립하여 보강 실시; 실습기간 재이수 교과목 출석 인정되지 않음','priorExamClockNotApplied':True}
(p/'metadata-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(a)
