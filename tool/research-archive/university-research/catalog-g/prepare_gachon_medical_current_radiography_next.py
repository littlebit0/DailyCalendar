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
PREVIOUS='3116-medical-lab-theory-next'
REVISION='3134-medical-current-radiography-next'
TARGETS=set('M3483001 M3604001 M0321001 M0926001 M3153001 M3470001 M3484001 M3575001 M3595001 M3722001 M3836001 M3836002 M3837001 M3837002 M3838001 M3838002 M3839001 M3839002'.split())
RADIOGRAPHY={c for c in TARGETS if c[:5] in {'M3836','M3837','M3838','M3839'}}
OMIT={'M3153001':[13]}
UNKNOWN_HOLIDAY={}
HELD_DATES={'M3604001':['2026-11-30'],'M3595001':['2026-12-01']}
EXTRA={
'M3483001':'현재 응급처치 교수 강의·토론의 공시 예약입니다.4~6주 문제 해설/국가고시 술기 점검 보강은 보충 학습 내용이며 확정된 추가 날짜·시각은 게시되지 않아 별도 보강 일정을 만들지 않았습니다.',
'M3604001':'입시 비대면 안내는11/30월~12/1화 해당일만 명시됩니다. 원월13:00~13:50중11/30만 방식 미확정으로 보류하며 같은14주차 수12/2원13:00~14:50예약은 전환일에 해당하지 않아 보존했습니다.',
'M0321001':'현재 치주학 이론·학생 사전준비·토론의 예약 계획입니다.12주 외과술/13주 임플란트 과정 동영상은 이론 사례자료이며 해당 주차 전체영상 대체 또는 실제 환자 시술 배정으로 만들지 않았습니다. 수업 자료를 사전에 인쇄해야 합니다.',
'M0926001':'현재 공중보건 사례·PPT·시청각 보조 자료를 사용하는 이론 강의 예약입니다. 국가시험 연계 내용은 학생 실제 외부시험 장소·시각으로 바꾸지 않았습니다.',
'M3153001':'현재 전문외상 이론·조별 논문발표·교내 시나리오 시뮬레이션 예약입니다.12주 화상은 화상환자의 의학적 학습 주제이며 실시간 화상회의가 아닙니다.13주 입시16주차 보강은 실제 날짜·시각 미확정으로 해당 원예약만 보류했습니다.',
'M3470001':'현재 피부계 물리치료는 사전자료와 매주 이론·사례·문제해결/국시 문제풀이입니다.7주 화상은 화상 손상 학습 주제이며 영상통화 수업 전환이 아닙니다.',
'M3484001':'현재 기초의학 교수강의·토론·팀원 오답정리의 공시예약입니다.4~6주 문제 해설/국가고시 술기 점검 보강은 학습 내용이며 별도 확정된 날짜·시각이 없어 허구 보강 이벤트를 만들지 않았습니다.',
'M3575001':'현재 노인·정신 응급 교수 이론·질의응답·토론의 예약입니다. 추석 휴업일은 학교 규정대로 제외하고 노인환자 병태생리학을 실제 외부환자 배정으로 만들지 않았습니다.',
'M3595001':'현재 영어 유전자세포치료 이론 예약입니다.11/30월~12/1화 해당일 비대면 안내 중 원화15:00~16:50의12/1만 실제방식 미확정으로 보류했습니다. 같은14주차 목12/3원15:00~15:50은 전환일이 아니므로 보존했습니다.',
'M3722001':'현재 생화학 강의중심 원수요일·목요일 예약입니다.14주 입시 비대면 안내는11/30월~12/1화 해당일만 명시되어 원수12/2·목12/3은 그 날짜와 일치하지 않습니다. 그 주차 전체를 임의 비대면 또는 휴강으로 바꾸지 않았습니다.'}
for offering in RADIOGRAPHY:
 EXTRA[offering]='현재 정상 공개 과목명/원분류 검색에서 교육필드가 일치하는 계획서의15주 교육 내용을 직접 재확인했습니다. 현장실습 과목 명칭만으로 학생 외부 병원 배정을 확정하지 않았습니다. 교재/PPT/부속기자재 이론 또는 기존 병원 실습 내용을 토대로 한 phantom모의검사·영상 분석의 학교 공시 예약입니다. 실습조 편성은 정규예약의 학습 활동이며 별도 학생군 교대 시각은 확정됐다고 주장하지 않습니다. 원교실 및 시각은 그대로, 별도 실제 병원배정 일정은 만들지 않았습니다.'
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 fresh={r['offering']:r for r in read('gachon-radiography9-current-weekly-education-recheck-20261008.json')['rows']}
 assert set(fresh)==RADIOGRAPHY|{'M3511001'}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3134PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
 for campus,source in [('global','20'),('medical','21')]:
  data=copy.deepcopy(read(f'gachon-{campus}-2026-2.published-regular-{PREVIOUS}-20261008.json'))
  for c in data['courses']:
   offering=c['courseCode']+c['section'];key=(source,offering)
   if offering not in TARGETS or c['scheduleStatus']!='unrecognized':continue
   report,base,review=reports[key],bases[key],reviews[key]
   if offering in RADIOGRAPHY:
    assert fresh[offering]['reportIdentity']==report['report']
    assert fresh[offering]['teachingMethodEducationalExcerpt']==report['teachingMethodEducationalExcerpt']
    assert len(fresh[offering]['weeklyEducationRows'])==15
    assert [r['week'] for r in fresh[offering]['weeklyEducationRows']]==list(range(1,16))
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
   meetings=[];held=list(HELD_DATES.get(offering,[]))
   for block in blocks:
    day=begin
    while day<=end:
     if day.isoweekday()==block['weekday']:
      if day.isoformat() in HOLIDAYS and offering in UNKNOWN_HOLIDAY:held.append(day.isoformat())
      if day.isoformat() not in HOLIDAYS and day.isoweekday()!=7 and not any(a<=day<=z for a,z in ranges) and day.isoformat() not in held:
       meetings.append({k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']})
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
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'narrowCurrentWeeklyRecheck':'gachon-radiography9-current-weekly-education-recheck-20261008.json' if offering in RADIOGRAPHY else None,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'narrowCurrentWeeklyRecheck':'gachon-radiography9-current-weekly-education-recheck-20261008.json' if offering in RADIOGRAPHY else None,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==18
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3134
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
