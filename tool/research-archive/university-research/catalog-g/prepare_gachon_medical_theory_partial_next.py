"""Narrow current AI/classroom reservation review; no recollection or production edits."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent
ROOT=Path(__file__).resolve().parent
PREVIOUS='3077-general-field-partial-next'
REVISION='3093-medical-theory-partial-next'
TARGETS=set('M2903001 M3709001 M3811001 M3878001 M2297001 M3014001 M3578001 M3646001 M3646002 M3677001 M3757002 M3757003 M3757004 M3757005 M0494001 M0494002'.split())
OMIT={'M2903001':[2],'M3811001':[13],'M2297001':[4],'M3677001':[4]}
UNKNOWN_HOLIDAY={'M2297001','M3757004','M3757005'}
EXTRA={
'M2903001':'현재1주9/2및3~15주의 수요일 원예약과 계획 날짜는 일치합니다.2주9/7은 원수요일과 다른 날짜의 영상·사전학습 및 교수 출장으로9/9원예약을 보류했습니다. 자료/PPT 업로드 및 질병 동영상은 이론 강의 보조 자료입니다.',
'M3709001':'바이오로직스 전용 분반 제한과 교재/PPT·영상 자료의 교수 이론 강의 예약을 보존했습니다. 추석 정규휴업일에 영상 출석 이벤트를 만들지 않았습니다.',
'M3811001':'교재 중심 방사선 해부학의 공시 예약입니다.10/5휴일 보강은 실제날짜·시각 미확정이며 추가하지 않았습니다.13주 입시 비대면 추후 재안내는 해당 정규예약에서 제외했습니다.',
'M3878001':'교수 이론·질의응답·발표의 공시 예약입니다.4주 농도계산 연습문제 보강은 추가 연습 내용으로 별도 확정 날짜·시각이 게시되지 않았고 허구 보강시각을 만들지 않았습니다.',
'M2297001':'말하기·듣기와 시청각 보조자료의 일반예약입니다.4주 추석 비대면 녹화 또는 화상수업은 휴강이 아닌 방식 미확정으로 해당 범위를 보류했습니다.',
'M3014001':'미술심리치료 사례 및 예술작품 감상은 교내 이론 강의·토론의 학습 주제입니다. 별도 임상 배정/학생 현장활동으로 둔갑시키지 않았습니다.',
'M3578001':'가상 사례·교수의 임상 경험과14주 비대면/AI 미래관계는 이론·추론의 학습 내용이며 실제14주 수업방식 전환이 아닙니다.',
'M3646001':'비판적 사고·종합 판단·학생 발표와 토론의 현재 공시 예약 계획입니다.',
'M3646002':'비판적 사고·종합 판단·학생 발표와 토론의 현재 공시 예약 계획입니다.',
'M3677001':'현재 수업 방법에 대면 강의가 명시되어 정상일의 모드를 대면으로 보존했습니다. PPT의 뉴스·영상은 보조 자료이고4주차 비대면은 실제 방식 미확정으로 제외했습니다.',
'M3757002':'현재7주(10/12월13:00~14:50)와14주(11/30월13:00~14:50)는 Zoom실시간 안내이며 해당 원시각 모드를 실시간으로 보존했습니다. 공휴일에도 실시간화상 대체라고 명시되어10/5동일원시각을 실시간으로 보존했습니다. 다른 날은 학생 실제 방식 선택을 존중하며 실기 시험의 별도시각을 만들지 않았습니다.',
'M3757003':'현재7주(10/12월15:00~16:50)와14주(11/30월15:00~16:50)는 Zoom실시간 안내이며 해당 원시각 모드를 실시간으로 보존했습니다. 공휴일에도 실시간화상 대체라고 명시되어10/5동일원시각을 실시간으로 보존했습니다. 다른 날은 학생 실제 방식 선택을 존중하며 실기 시험의 별도시각을 만들지 않았습니다.',
'M3757004':'교내 Python이론·실습 예약이며 온라인퀴즈 시험 장소는 강의실이라고 명시합니다. 휴일 영상 또는 실시간 대체는 휴강이 아닌 방식 미확정으로9/25·10/9원예약을 보류했습니다.',
'M3757005':'교내 Python이론·실습 예약이며 온라인퀴즈 시험 장소는 강의실이라고 명시합니다. 휴일 영상 또는 실시간 대체는 휴강이 아닌 방식 미확정으로9/25·10/9원예약을 보류했습니다.',
'M0494001':'현재 성인간호 이론·PBL·팀활동과 간호중재 동영상 사례 자료의 공시 예약입니다. 삽관·간이식 동영상은 학생 실제 병원 임상배정 또는 전체영상 주차가 아니라 수업 내용의 사례 자료입니다.',
'M0494002':'현재 성인간호 강의·플립러닝·팀활동과 간호중재 동영상 사례 자료의 공시 예약입니다. 삽관·간이식 동영상은 학생 실제 병원 임상배정 또는 전체영상 주차가 아니라 수업 내용의 사례 자료입니다.'}
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3093PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
 for campus,source in [('global','20'),('medical','21')]:
  data=copy.deepcopy(read(f'gachon-{campus}-2026-2.published-regular-{PREVIOUS}-20261008.json'))
  for c in data['courses']:
   offering=c['courseCode']+c['section'];key=(source,offering)
   if offering not in TARGETS or c['scheduleStatus']!='unrecognized':continue
   report,base,review=reports[key],bases[key],reviews[key]
   assert current_period_weekly_rows_consistent(report,base)
   assert len(report['weeklyRows'])==15 and not report['potentialDifferentTermStatement']
   assert all(report['report'][k] for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'])
   assert not base['blockingReasons'] and base['schedulingDecision']=='regularCandidate'
   assert report['educationalParserVersion']==6
   assert not any(w['operatingContextLimitReached'] or w['operatingContextTruncationDetected'] for w in report['weeklyRows'])
   assert c['period']['startDate']=='2026-09-01' and c['period']['endDate']=='2026-12-14'
   blocks=copy.deepcopy(base['schedules']);assert blocks
   omitted=[w for w in report['weeklyRows'] if w['week'] in OMIT.get(offering,[])]
   ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
   begin,end=(dt.date.fromisoformat(c['period'][k]) for k in ['startDate','endDate'])
   meetings=[];held=[]
   for block in blocks:
    day=begin
    while day<=end:
     if day.isoweekday()==block['weekday']:
      if day.isoformat() in HOLIDAYS and offering in UNKNOWN_HOLIDAY:held.append(day.isoformat())
      if (day.isoformat() not in HOLIDAYS or offering in {'M3757002','M3757003'} and day.isoformat()=='2026-10-05') and day.isoweekday()!=7 and not any(a<=day<=z for a,z in ranges):
       meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
       if offering=='M3677001':meeting['deliveryMode']='inPerson'
       if offering in {'M3757002','M3757003'} and day.isoformat() in {'2026-10-05','2026-10-12','2026-11-30'}:meeting['deliveryMode']='liveOnline'
       meetings.append(meeting)
     day+=dt.timedelta(days=1)
   assert meetings
   prior=copy.deepcopy(c['departmentRemarks']);auto='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
   remarks={d:'\n'.join([*(s for s in r.split('\n') if s!=auto),NOTE]) for d,r in prior.items()}
   suffix=[EXTRA.get(offering,'현재 이론·AI 실습의 정규 공시 예약 계획입니다. 온라인 도구·사이버캠퍼스 과제 제출은 수업 시각 변경을 의미하지 않습니다. 온라인퀴즈의 시험 장소가 강의실이라고 명시되면 원 예약만 보존하며 별도 시험 시각을 만들지 않았습니다.')]
   for w in omitted:suffix.append(f'현재{w["week"]}주차({w["startMonthDay"]}~{w["endMonthDay"]}) 원안내: {" / ".join(w["operatingContexts"])}. 이 범위는 실제 방식·대체평가·보강 시각 미확정으로 정규 예약 일정에서 제외했습니다. 휴강 확정과 동일시하지 않았습니다.')
   if held:suffix.append('휴강이 아닌 방식 미확정 범위: '+', '.join(sorted(set(held)))+'. 온라인 또는 영상 대체의 실제 방식/시각을 강제하지 않았습니다.')
   method=report.get('teachingMethodEducationalExcerpt','')
   suffix.append('현재 교육용 수업 안내: '+method)
   remarks={d:r+'\n'+'\n'.join(suffix) for d,r in remarks.items()}
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'inPersonFromCurrentMethod' if offering=='M3677001' else 'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'explicitHolidayClassDate':'2026-10-05' if offering in {'M3757002','M3757003'} else None,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'explicitHolidayClassDate':'2026-10-05' if offering in {'M3757002','M3757003'} else None,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==16
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3093
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
