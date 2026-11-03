from pathlib import Path
from datetime import date,timedelta
import json,copy,re,hashlib,collections
P=Path(__file__).parent
OLD=P.parent.parent/'catalog-f'/'chosun'
previous=json.loads((OLD/'chosun-unknown-2026-2.future-nurse-native135-partial-v2.json').read_text())
source=json.loads((P/'current-final-educational-workbook-comparison.json').read_text())
current={s['sheet']:s for s in source['sheets']}
new=copy.deepcopy(previous);proof=[]
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-09-29','2026-10-03','2026-10-05','2026-10-09'}
for c in new['courses']:
 old=c['sourceEducation']['nativePublicBlock']
 if 'sheet' not in old:continue
 sh=current[old['sheet']]
 matched=[r for r in sh['courseCells'] if re.search(r'\d{5}-\d{2}',r['nativeCellText']).group()==old['nativeReference']]
 if len(matched)!=1:
  if len(matched)==0:
   assert not c['schedules']
   c['sourceEducation']['currentFinalWorkbookMissing']=dict(sourceURL=source['sourceUrl'],sourceSHA256=source['sourceSHA256'],noticeDate='2026-09-01',closedCourseConfirmed=False,note='최종 미래학부 첨부에 동일 복합번호 교육 블록 없음. 전체 개설/폐강 조회가 아니므로 폐강을 확정하지 않으며 기존 미예약 객체를 원문 provenance로 보존합니다.')
  continue
 r=matched[0]
 if r['nativeCellText']==old['nativeCellText'] and r['cell']==old['cell'] and r['mergedRange']==old['mergedRange']:continue
 lines=r['nativeCellText'].splitlines();idx=next(i for i,s in enumerate(lines) if re.search(r'\d{5}-\d{2}',s));m=re.search(r'\d{5}-\d{2}',lines[idx]);title=''.join(x.strip() for x in lines[:idx])+lines[idx][:m.start()].strip();after=lines[idx+1:]
 teacher,room,mode=[x.strip() for x in after[:3]]
 assert title==c['courseName'] and (teacher==c['professor'] or not c['professor'])
 assert mode=='대면' and teacher and room
 clocks={x['row']:x for x in sh['clockRows']};first=clocks[r['minRow']];last=clocks[r['maxRow']]
 def minutes(t):h,m=map(int,t.split(':'));return h*60+m
 start=minutes(first['values'][2].split('~')[0]);end=minutes(last['values'][2].split('~')[1]);day=(r['minColumn']-4)//6+1
 assert (r['maxColumn']-4)//6+1==day and 1<=day<=6
 assert next(h['literal'] for h in sh['weekdayHeaderCells'] if h['column']==4+(day-1)*6)=='월화수목금토'[day-1]
 assert r['fill']==old['nativeClassificationFill']
 assert not(day==3 and start<780 and end>720)
 dates=[];d=date(2026,9,1)
 while d<=date(2026,12,7):
  ds=d.isoformat()
  if d.isoweekday()==day and ds not in holidays and not '2026-10-20'<=ds<='2026-10-26':dates.append(dict(date=ds,weekday=day,startMinute=start,endMinute=end,classroom=room))
  d+=timedelta(days=1)
 prior=copy.deepcopy(c);c.update(professor=teacher,sourceClassroom=room,sourceSchedule='월화수목금토'[day-1]+' '+first['values'][1]+'~'+last['values'][1]+' '+first['values'][2].split('~')[0]+'~'+last['values'][2].split('~')[1],schedules=dates,scheduleStatus='scheduled',period=dict(startDate='2026-09-01',endDate='2026-12-07'))
 note=next(iter(prior['departmentRemarks'].values())).split(' 날짜 변환 보류 사유:',1)[0].replace('원문 방식:'+old['nativeDeliveryMode']+'.','원문 방식:대면.')
 note+=' 현재9/1 공식 최종 시간표의 동일 복합번호·제목을 유일하게 대응했습니다. 최신 원문 위치:'+r['sheet']+'/'+r['cell']+'. 기존 내부 문서 위치 sourceId는 연속성 식별자이며 현재 원문 위치를 공식 수강번호로 주장하지 않습니다. 기존8/27 교육 기록은 원문 provenance로 보존하며 현재 교수·요일·교시·실·방식만 새 원문 그대로 정정합니다.'
 if r['cell']!=old['cell']:note+=' 최신 문서에서 요일 이동되어 종전 문서 위치의 요일/시각은 더 이상 현재 예약에 사용하지 않습니다. 현재 대상 학생그룹은 최종표 실제 열머리글로 다시 연결했으며 해당 강좌 전체공개 조회가 아닙니다.'
 c['remarks']=note
 if r['cell']!=old['cell']:
  c['departments']=[old['sheet']+' 미래융합학부 / '+g['literal'] for g in sh['nativeStudentGroupCells'] if r['minColumn']<=g['column']<=r['maxColumn']]
  c['departmentClassifications']={}
  c['departmentCredits']={}
 c['departmentRemarks']={k:note for k in c['departments']};c['sourceEducation'].update(originalFrozenPublicBlock=copy.deepcopy(old),currentFinalPublicBlock=r,currentFinalOwnClockRows=[clocks[i] for i in range(r['minRow'],r['maxRow']+1)],currentFinalPublicSourceURL=source['sourceUrl'],currentFinalSourceSHA256=source['sourceSHA256'],currentFinalNoticeDate='2026-09-01',currentFinalActualAttendanceConfirmed=False)
 proof.append(dict(sourceId=c['sourceId'],nativeReference=old['nativeReference'],oldCell=old['cell'],currentCell=r['cell'],sheet=r['sheet'],priorScheduled=bool(prior['schedules']),nowScheduled=True,priorDated=len(prior['schedules']),newDated=len(dates),weekday=day,startMinute=start,endMinute=end,classroom=room,professor=teacher,originalFrozenPublicBlock=old,currentFinalPublicBlock=r,currentOwnClocks=[clocks[i] for i in range(r['minRow'],r['maxRow']+1)],oldCourseSHA256=hashlib.sha256(json.dumps(prior,ensure_ascii=False,sort_keys=True).encode()).hexdigest()))
assert len(proof)==13
priorMap={c['sourceId']:c for c in previous['courses']};changed={r['sourceId'] for r in proof}|{c['sourceId'] for c in new['courses'] if 'currentFinalWorkbookMissing' in c['sourceEducation']}
assert all(c==priorMap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in changed)
assert new['courses'][71:]==previous['courses'][71:]
new.update(candidateRevision='current-final-future-source-review-v4',publishedDate=previous['publishedDate'],sourceUrl=source['noticeUrl'],sourceUrls=list(dict.fromkeys(previous['sourceUrls']+[source['noticeUrl'],source['sourceUrl']])),sourceCurrentFinalURL=source['noticeUrl'],predecessorSHA256=hashlib.sha256((OLD/'chosun-unknown-2026-2.future-nurse-native135-partial-v2.json').read_bytes()).hexdigest())
def write(n,v):(P/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
write('chosun-unknown-2026-2.current-final-future-source-review-candidate-v4.json',new)
write('current-final-native-operating-correction-proof.json',proof)
write('candidate-audit.prepared.json',dict(nativeDocumentBlocks=len(new['courses']),priorScheduled=sum(bool(c['schedules']) for c in previous['courses']),priorDates=sum(len(c['schedules']) for c in previous['courses']),scheduled=sum(bool(c['schedules']) for c in new['courses']),dates=sum(len(c['schedules']) for c in new['courses']),newEligible=sum(not r['priorScheduled'] for r in proof),currentCorrectedPriorScheduled=sum(r['priorScheduled'] for r in proof),operationCorrectedObjects=len(proof),historicalMissingHeldMetadataAnnotated=1,changedObjects=len(changed),other121CourseObjectsDeepUnchanged=True,nursing64DeepUnchanged=True,wholeSchoolCompletionClaim=False,actualAttendanceConfirmed=False,SDKUsed=False,productChanged=False))
print(json.loads((P/'candidate-audit.prepared.json').read_text()))
