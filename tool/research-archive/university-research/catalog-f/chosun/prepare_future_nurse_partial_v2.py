"""Append current nursing educational cells without changing the frozen first candidate."""
from pathlib import Path
from datetime import date,timedelta
import json,hashlib,collections
R=Path(__file__).parent
base=json.loads((R/'chosun-unknown-2026-2.future-native71-partial-v1.json').read_text())
source=json.loads((R/'chosun-nurse-current-education-source-20261008.json').read_text())
closure=json.loads((R/'chosun-nurse-current-closure-education-receipt-20261008.json').read_text())
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-09-29','2026-10-03','2026-10-05','2026-10-09'}
for r in source['educationRows']:
 title=r['courseName'];section=r['section'];reasons=r['heldReasons'];first=r['firstHeader'];last=r['lastHeader']
 assert not any(n in title.replace(' ','') for n in ['환자안전','건강한노화','임상영양학'])
 assert not ('건강사정실습' in title and section=='05')
 assert not ('기본간호학실습' in title and section=='05')
 eligible=not reasons;meetings=[];d=date(2026,9,1)
 while d<=date(2026,12,7):
  ds=d.isoformat()
  if eligible and d.isoweekday()==r['weekday'] and ds not in holidays and not '2026-10-20'<=ds<='2026-10-26':meetings.append({'date':ds,'weekday':r['weekday'],'startMinute':first['startMinute'],'endMinute':last['endMinute'],'classroom':r['classroom']})
  d+=timedelta(days=1)
 group=f"간호학과 {r['grade']}학년"
 note=('공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 현재9월7일 시행용 간호학과 학부1~4학년 표의 단일 교육용 셀입니다. 같은 강좌의 여러 요일·시간 셀은 별도 문서 블록으로 보존하며 전체 강좌 수라고 주장하지 않습니다. 과목코드·학점·이수구분은 이 표에 미공개로 빈 값/미확인입니다. 괄호 숫자 분반은 현재 공지의 명시 분반 변경과 표의 동일 제목·숫자 표기로 확인했습니다. 원문 실 그대로이며 물리 캠퍼스명 연결 증거는 없어 unknown입니다. 시각은 셀의 실제 경계가 직접 인쇄된 HH:mm 교시 header 경계와 일치할 때만 연결하고 중간 경계의 분을 추정하지 않습니다. 자체9월1일 개강~첫 보강일12월8일 전12월7일 정규 주간 예약이며 자체 중간고사10월20~26일·명시휴업일9월24~26일/9월29일/10월5일/10월9일은 제외합니다.10월3일 국가공휴일은 학교 실제 토요일 휴강 미확인으로 보수적 보류합니다. 실제 과목별 시험·보강 날짜와 출석을 확정하지 않습니다. 종강일 명시 없음으로 dataset termEndDate는 만들지 않았습니다. 상급학년 임상집중·실습 회전 일정·배정 교수·정확 교시 경계 미확인은 보류합니다. 교수란 없는 EAL 셀의 본관은 건물명이며 교수명으로 변환하지 않습니다. 사용자 강의방식3종을 원문 방식으로 덮어쓰지 않습니다. 현재 간호학과 공지폐강5개는 원문으로 별도 보존하고 이번 단일셀 선택에 같은 과목·분반이 없음을 대조했습니다. 기본간호학실습(05) 공지와 실습2 제목은 동일강좌 확정 없이 보수적으로05 보류 대상입니다. 최신 학교 전체 폐강 대조는 미완료입니다. ')
 if reasons:note+='날짜 변환 보류 사유: '+', '.join(reasons)+'. '
 base['courses'].append({'sourceId':r['sourceId'],'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':title,'section':section,'professor':r['professor'],'credits':None,'classification':'','departments':[group],'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{group:note},'sourceSchedule':r['nativeCellText'],'sourceClassroom':r['classroom'],'period':{'startDate':'2026-09-01','endDate':'2026-12-07'} if eligible else None,'scheduleStatus':'scheduled' if eligible else 'unrecognized','schedules':meetings,'sourceEducation':{'nativePublicBlock':r,'referenceKind':'internalDocumentLocator','wholeSchoolCompletionClaim':False,'campusPhysicalProof':False,'actualAttendanceConfirmed':False,'currentDepartmentClosureCompared':True,'latestWholeClosureCompared':False}})
base['sourceUrls']=[base['sourceUrl'],closure['noticeUrl'],source['sourceUrl']]
base['publishedDate']='2026-09-07';base['candidateRevision']='future-nurse-native135-partial-v2'
n='chosun-unknown-2026-2.future-nurse-native135-partial-v2.json';p=R/n;p.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
audit={'file':n,'SHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'nativeDocumentBlocks':len(base['courses']),'scheduledBlocks':sum(bool(c['schedules']) for c in base['courses']),'heldBlocks':sum(not c['schedules'] for c in base['courses']),'datedSlots':sum(len(c['schedules']) for c in base['courses']),'additionalNursingDocumentCells':64,'additionalNursingScheduledCells':24,'wholeSchoolCompletionClaim':False,'productionChanged':False}
(R/'chosun-future-nurse-native135-partial-v2-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(audit)
