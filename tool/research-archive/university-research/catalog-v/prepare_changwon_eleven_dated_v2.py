"""Preserve five frozen plans; add six individually reviewed dated plans."""
import datetime as dt
import hashlib
import json
from pathlib import Path
root=Path(__file__).resolve().parent
base=json.loads((root/'changwon-unknown-2026-2.five-dated-v1.json').read_text())
byid={f"{c['courseCode']}-{c['section']}":c for c in base['courses']}
selected={}
choir_common='09-01 09-03 09-08 09-10 09-15 09-17 09-22 09-29 10-01 10-06 10-08 10-13 10-15 10-20 10-22 10-27 10-29 11-10 11-12 11-17 11-26'
for code in ['MUA0530','MUA0532','MUA0737','MUA0741']:
 dates=choir_common
 if code!='MUA0532': dates+=' 11-03 11-05'
 selected[code+'-00']=(dates,'합창 개별 계획의 날짜만 적용합니다. 원문 11월14일(화)·16일(목)은 2026년 실제 요일과 달라 보류했습니다. 11월19일 기말고사는 출석 종료 시각 미확인, 11월24일 기말고사는 공통 임시휴강 예정과 충돌하여 보류했습니다. 공연의 실제 출석 시각·장소, 필요시 수업 및 보강은 미확인입니다.'+(' 10월31일(화)·11월2일(목) 역시 날짜·요일 충돌로 보류했습니다.' if code=='MUA0532' else ''))
selected['NSA0126-00']=('09-02 09-09 09-16 09-30 10-07 10-14 10-21 10-28 11-04 11-11 11-18 11-25 12-02 12-09','주차 번호가 아닌 명시된 날짜를 적용합니다. 9월23일 등 원문에 없는 수업은 만들지 않습니다. 10월21일 중간고사는 명시된 11:00–12:00/31404를 적용합니다. 12월16일 기말고사의 종료 시각 미확인으로 보류했습니다. 12월9일 강의는 공통 보강주에도 개별 계획의 명시된 수업으로 보존합니다.')
selected['GEA8002-00']=('09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-03 11-10 11-17 12-01 12-15','11월24일은 개별 계획에 명시된 임시휴강으로 제외합니다. 12월12일 보강은 수업 내용·개별 출석 시각 별도 공지 예정이므로 보류했습니다. 12월15일 종강 보고는 개별 계획에 명시된 대면 수업으로 적용했습니다. 동영상·실시간+동영상의01분반은 별도 출석 운영 미확인으로 일정 미생성을 유지합니다.')
common='공개 개별 강의계획의 날짜 및 예약 블록 시간입니다. 실제 출석·개별 최신 변경이 모두 확인된 것은 아닙니다. 교실별 물리 캠퍼스는 확인되지 않았습니다. 공통 시험·보강을 임의로 생성하지 않습니다.'
audit=[]
for key,(dates,note) in selected.items():
 c=byid[key];planfile=root/'public-plans-20261008'/f'{key}.json';plan=json.loads(planfile.read_text());assert plan['fields']['수업운영방식']=='대면'
 c['sourceEducation']['currentPublicPlan']=plan
 meetings=[]
 for text in dates.split():
  date='2026-'+text;day=dt.date.fromisoformat(date)
  if key.startswith('MUA'):
   assert day.weekday() in [1,3]
   start,end=960,1080;room='63402' if day.weekday()==1 else '63404'
   if text=='10-20':room='61106'
  elif key=='NSA0126-00':
   assert day.weekday()==2
   start,end=(660,720) if text=='10-21' else (660,780);room='31404'
  else:
   assert day.weekday()==1
   start,end=840,960;room='CWNU가온홀'
  meetings.append(dict(date=date,weekday=day.isoweekday(),startMinute=start,endMinute=end,classroom=room,deliveryMode='inPerson'))
 c['schedules']=meetings;c['scheduleStatus']='scheduled'
 existing=c['remarks'].split('일반·집중·원격 수업의 개별 날짜')[0]
 c['remarks']=existing+note+'\n'+common
 c['departmentRemarks']={k:c['remarks'] for k in c['departmentRemarks']}
 audit.append(dict(key=key,count=len(meetings),planSHA256=hashlib.sha256(planfile.read_bytes()).hexdigest(),sourceNotes=note))
base['candidateRevision']='eleven-dated-v2';base['researchOnly']=True;base['completionClaim']=False
out=root/'changwon-unknown-2026-2.eleven-dated-v2.json';out.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
report=dict(originalNativeRows=len(base['courses']),scheduled=sum(bool(c['schedules']) for c in base['courses']),datedMeetings=sum(len(c['schedules']) for c in base['courses']),newReviewedPlans=audit,sha256=hashlib.sha256(out.read_bytes()).hexdigest(),wholeOperatingReviewComplete=False,completionClaim=False)
(root/'changwon-eleven-dated-v2-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(report)
