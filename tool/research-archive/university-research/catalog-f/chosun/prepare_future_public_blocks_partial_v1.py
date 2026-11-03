"""Current explicit future-college blocks, actual clocks; ambiguous references stay whole."""
from pathlib import Path
from datetime import date,timedelta
import json,re,hashlib,urllib.parse,collections
R=Path(__file__).parent
def save(n,j):
 p=R/n;p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
source=json.loads((R/'chosun-future-current-education-source-20261008.json').read_text());sheets={s['sheet']:s for s in source['sheets']};rows=[];courses=[]
cal=json.loads((R/'chosun-current-calendar-education-receipt-20261008.json').read_text());events=cal['educationalEvents'];assert any(e['startDate']=='2026-10-20' and e['endDate']=='2026-10-26' and e['nativeTitle']=='중간고사' for e in events)
assert any(e['startDate']=='2026-12-08' and e['nativeTitle'].startswith('[휴업일에 따른 수업일]') for e in events)
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-09-29','2026-10-03','2026-10-05','2026-10-09'}
for c in source['courseCells']:
 if '2학기' not in c['sheetHeading']:continue
 lines=c['nativeCellText'].splitlines();idx=next(i for i,p in enumerate(lines) if re.search(r'\d{5}-\d{2}',p));match=re.search(r'\d{5}-\d{2}',lines[idx]);ref=match.group();title=''.join(p.strip() for p in lines[:idx])+lines[idx][:match.start()].strip();after=lines[idx+1:];assert len(after)>=3
 teacher=after[0].strip();room=after[1].strip();mode=after[2].strip();extra=[p.strip() for p in after[3:] if p.strip()]
 sh=sheets[c['sheet']];clock={r['row']:r for r in sh['clockRows']};first=clock[c['minRow']];last=clock[c['maxRow']]
 day=(c['minColumn']-4)//6+1;assert (c['maxColumn']-4)//6+1==day and 1<=day<=6
 assert next(h['nativeWeekday'] for h in sh['weekdayHeaders'] if h['column']==4+(day-1)*6)=='월화수목금토'[day-1]
 groups=[f"{c['sheet']} 미래융합학부 / "+str(g['nativeStudentGroup']) for g in sh['nativeStudentGroups'] if c['minColumn']<=g['column']<=c['maxColumn']]
 classifications=[x['nativeClassification'] for x in sh['legend'] if x['fill']==c['fill']];classification=classifications[0] if len(classifications)==1 else ''
 sid=source['sourceUrl']+'#sheet='+urllib.parse.quote(c['sheet'],safe='')+'&cell='+c['cell'];reasons=[]
 if mode!='대면':reasons.append('nativeRemoteOrBlendedDateAllocationUnconfirmed')
 if not teacher or any(x in teacher for x in ['미정','예정','신규']):reasons.append('nativeProfessorUnassigned')
 if not room or any(x in room for x in ['미정','예정','현장','온라인','사이버']):reasons.append('exactPhysicalRoomUnconfirmed')
 if day==3 and first['startMinute']<750 and last['endMinute']>720:reasons.append('nativeWednesdayCUTIMEConflict')
 eligible=not reasons;meetings=[];d=date(2026,9,1)
 while d<=date(2026,12,7):
  ds=d.isoformat()
  if eligible and d.isoweekday()==day and ds not in holidays and not '2026-10-20'<=ds<='2026-10-26':meetings.append({'date':ds,'weekday':day,'startMinute':first['startMinute'],'endMinute':last['endMinute'],'classroom':room})
  d+=timedelta(days=1)
 native={'sourceId':sid,'sheet':c['sheet'],'cell':c['cell'],'nativeCellText':c['nativeCellText'],'nativeHeading':c['sheetHeading'],'nativeReference':ref,'nativeReferenceSeparationDefinitionConfirmed':False,'courseName':title,'professor':teacher,'classroom':room,'nativeDeliveryMode':mode,'nativeExtraRemarks':extra,'nativeClassification':classification,'nativeClassificationFill':c['fill'],'nativeStudentGroups':groups,'mergedRange':c['mergedRange'],'clockRows':[clock[r] for r in range(c['minRow'],c['maxRow']+1)],'weekday':day,'startMinute':first['startMinute'],'endMinute':last['endMinute'],'heldReasons':reasons,'status':'scheduled' if eligible else 'held'};rows.append(native)
 note=('공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. '
  f'원문 복합번호 {ref}는 공개되어 그대로 보존하지만 과목코드/분반의 분리 정의를 확인하지 못하여 모델 코드·분반 필드는 빈 값입니다. '
  '학점은 이 표에 미공개로 미확인입니다. 원문 색상 legend는 보존하며 정확 동일 fill로 직접 연결된 구분만 사용합니다. '
  '자체9월1일 개강, 중간고사10월20~26일·12월8~14일 휴업일에 따른 수업일·기말고사12월15~21일이 직접 공개되어 정규 예약은12월7일까지이며 중간고사 주는 보류합니다. '
  '추석9월24~26일·개교기념일9월29일·대체공휴일10월5일·한글날10월9일은 자체 휴업일 원문에 따라 제외했고10월3일 국가 공휴일은 토요일 강좌의 실제 휴강 미확인 상태로 보수적 보류했습니다. '
  '학교 보강일은 공개되어도 해당 강좌 실제 보강 시각·실을 연결 확인하지 못하여 임의 요일 대체를 생성하지 않습니다. 종강일은 명시되지 않아 dataset termEndDate를 만들지 않았습니다. '
  f'원문 방식:{mode}. 원격/블렌디드 날짜 배정은 미확인으로 보류하며 사용자 강의방식3종을 원문 방식으로 덮어쓰지 않습니다. '
  '실은 현재 원문 그대로이며 물리 캠퍼스 mapping 직접 증거가 없어 unknown입니다. 같은 파일의1학년1학기 heading9블록은 현재2학기로 확대하지 않았습니다. 최신 학교전체/해당 단과대학 전체 폐강 대조는 미완료입니다. ')
 if extra:note+=' 원문 교육용 비고: '+' / '.join(extra)+'. '
 if reasons:note+=' 날짜 변환 보류 사유: '+', '.join(reasons)+'. '
 courses.append({'sourceId':sid,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':title,'section':'','professor':teacher,'credits':None,'classification':classification,'departments':groups,'departmentClassifications':{},'departmentCredits':{},'departmentRemarks':{g:note for g in groups},'sourceSchedule':'월화수목금토'[day-1]+' '+first['nativePeriod']+'~'+last['nativePeriod']+' '+first['nativeClock'].split('~')[0]+'~'+last['nativeClock'].split('~')[1],'sourceClassroom':room,'period':{'startDate':'2026-09-01','endDate':'2026-12-07'} if eligible else None,'scheduleStatus':'scheduled' if eligible else 'unrecognized','schedules':meetings,'sourceEducation':{'nativePublicBlock':native,'referenceKind':'internalDocumentLocator','wholeSchoolCompletionClaim':False,'campusPhysicalProof':False,'actualAttendanceConfirmed':False,'latestWholeClosureCompared':False}})
assert len(courses)==71 and len({c['sourceId'] for c in courses})==71
save('chosun-future-native71-source-selection-20261008.json',{'sourceUrl':source['sourceUrl'],'sourceSHA256':source['sourceSHA256'],'educationRows':rows,'firstGradeSemesterConflictBlocksHeldOutsideCurrentCandidate':9,'wholeSchoolCompletionClaim':False})
n='chosun-unknown-2026-2.future-native71-partial-v1.json';sha=save(n,{'schemaVersion':2,'universityId':'chosun','institutionId':'institution:academyinfo:0000172','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-27','sourceUrl':source['noticeUrl'],'candidateRevision':'future-native71-partial-v1','termStartDate':'2026-09-01','completionClaim':False,'courses':courses})
audit={'file':n,'SHA256':sha,'nativeDocumentBlocks':71,'scheduledBlocks':sum(bool(c['schedules']) for c in courses),'heldBlocks':sum(not c['schedules'] for c in courses),'datedSlots':sum(len(c['schedules']) for c in courses),'knownClassificationBlocks':sum(bool(c['classification']) for c in courses),'nativeReferenceSeparationConfirmed':False,'wholeSchoolCompletionClaim':False,'productionChanged':False};save('chosun-future-native71-partial-v1-audit.json',audit);print(audit)
