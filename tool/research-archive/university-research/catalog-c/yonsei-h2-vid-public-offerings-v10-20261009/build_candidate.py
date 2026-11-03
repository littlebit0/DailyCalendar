import json,pathlib,copy,datetime,hashlib
from parse_mirae_education_groups import parse
p=pathlib.Path(__file__).parent
base=json.loads((p/'baseline-mirae-v9.json').read_text());out=copy.deepcopy(base)
w=json.loads((p/'workbook-extracted.json').read_text())['Sheet1']['rows'];rows={r['row']:r['cells'] for r in w}
ids={'VID2006-01-01':13,'VID2006-02-01':14,'VID3033-01-01':20,'VID3033-02-01':21,'VID3036-01-01':23,'VID3036-02-01':24,'VID4002-01-01':27,'VID4002-02-01':28}
dates=[];d=datetime.date(2026,9,1)
while d<=datetime.date(2026,12,7):
 if d.isoformat() not in {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'} and not datetime.date(2026,10,20)<=d<=datetime.date(2026,10,26):dates.append(d)
 d+=datetime.timedelta(days=1)
proof=[]
for c in out['courses']:
 e=c['sourceEducation'][0];identity=e['subjtnbCorsePrcts']
 if identity not in ids:continue
 n=ids[identity];r=rows[n];assert not c['schedules'] and e['subjtClNm'] is None and e['atntnMattrDesc'] is None and e['rmvlcYn']=='0' and e['lessnSessnDivNm']=='학기'
 assert r[f'B{n}']==c['courseCode'] and r[f'D{n}']==int(c['section']) and r[f'G{n}']==c['professor'] and r[f'F{n}']==c['credits']
 time=r[f'H{n}'];room=r[f'I{n}'];expanded=time[:time.index('(')+1]+time[0]+time[time.index('(')+1:]
 assert expanded==c['sourceSchedule'] and room==c['sourceClassroom']
 slots=parse(c['sourceSchedule'],room);assert len(slots)==4
 plans=[{'weekday':s['weekday'],'sourcePeriod':s['nativePeriod'],'sourceGroupKind':s['nativeGroupKind'],'startMinute':s['startMinute'],'endMinute':s['endMinute'],'classroom':s['classroom'],'deliveryMode':'inPerson','date':d.isoformat()} for d in dates for s in slots if d.isoweekday()==s['weekday']]
 old=copy.deepcopy(c);c['schedules']=plans;c['scheduleStatus']='scheduled';c['priorHeldResearchRemarks']=old['remarks'];c['priorHeldDepartmentRemarks']=old['departmentRemarks']
 note='\n학과 공식2026-2 개설 교과목표가 이 강좌의 수업시간과 물리 강의실(실습 포함)을 직접 명시합니다. 원문 수업 유형 빈 값은 그대로 보존하며 영상·혼합으로 추정하지 않습니다. 교시와 실습 표기는 미래캠퍼스 자체 근거만 사용합니다. 공개 예약 계획이며 실제 출석·개별 변경·시험 운영의 확정은 아닙니다.'
 c['remarks']=old['remarks'].split('\n일정 보류:')[0]+note;c['departmentRemarks']={k:v.split('\n일정 보류:')[0]+note for k,v in old['departmentRemarks'].items()}
 c['publishedDepartmentAssignmentProof']={'sourceURL':'https://vd.yonsei.ac.kr/vd/community/notice.do?articleNo=76360&attachNo=61098&mode=download','noticeDate':'2026-08-10','sheet':'Sheet1','row':n,'rawCells':r,'nativeClassModePreserved':None,'physicalRoomAndTimeDirectlyPrinted':True,'nativePracticumSectionPreserved':c['nativePracticumSection'],'individualAttendanceVerified':False}
 for k in old:
  if k not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[k]==old[k]
 proof.append({'sourceId':c['sourceId'],'row':n,'plans':len(plans),'slots':slots,'sourceCells':r})
assert len(proof)==8 and sum(x['plans'] for x in proof)==396
for b,c in zip(base['courses'],out['courses']):
 if b['sourceEducation'][0]['subjtnbCorsePrcts'] not in ids:assert b==c
out['completionClaim']=False
(p/'yonsei-mirae-2026-2.vid-v10.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
(p/'native8-exact-department-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCourses':8,'newMeetings':396,'priorScheduled':994,'priorMeetings':34972,'candidateScheduled':1002,'candidateMeetings':35368,'byCourse':proof},ensure_ascii=False,indent=2)+'\n')
print('8 / 396; whole1210 preserved; total1002 /35368')
