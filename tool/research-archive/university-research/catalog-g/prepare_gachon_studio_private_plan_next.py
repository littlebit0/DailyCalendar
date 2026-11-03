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
PREVIOUS='3179-academic-project-partial-v2-next'
REVISION='3191-studio-private-plan-next'
TARGETS=set('12542001 12542002 12542003 12542004 12897002 13083001 13203003 13203015 13206016 13206021 13206028 13210002'.split())
OMIT={'12542001':[15],'12542002':[15],'12542003':[15],'12542004':[15],'13206016':[13,14]}
UNKNOWN_HOLIDAY={}
HELD_DATES={f'12542{i:03}':['2026-10-13','2026-12-01'] for i in range(1,5)}|{'13083001':['2026-11-30']}
EXTRA={
'12897002':'현재 해당002분반 방법의 사전영상·대면강의·AI그룹토론을 보존합니다.다른001분반의1시간영상/2시간교실 할당을 이분반에 그대로 적용하지 않았습니다.원정규예약 계획이며 학생은 해당분반의 실제 모드를 선택하고 사전학습 배정을 확인해야 합니다.영상의 별도 시각은 만들지 않았습니다.',
'13083001':'현재 이론·문답·연습문제 토론의 원월요일/수요일 예약입니다.13주11/30월만 비대면이라고 명시되어 그 월요일 시각만 실제방식 미확정으로 보류하고 같은 주11/25수요일은 보존했습니다.1시간강의/2시간실습과평가3시간은 교수의 수업 구성 표기로 원3교시예약을 보존하되3시간 연속시험의 별도날짜·180분시각은 만들지 않았습니다.'}
for offering in TARGETS:
 if offering.startswith('12542'):
  EXTRA[offering]='현재 매시간 Desk Critic·공개 Presentation의 설계스튜디오 예약입니다.10/13·12/1화요일 평가는6층홀 전시로 원교실과 다르며 실제 평가시각이 미확정이라 그 날 원교실 예약만 보류했습니다.같은 주 금요일10/16·12/4의 정상스튜디오 예약은 보존했습니다.15주 최종영상/설계일지/결과물 제출은 실제 원시각 참석 미확정으로 보류했습니다.최대1분은 과제 영상 길이,1/500등은모형스케일이며수업시각이 아닙니다.별도요청 크리틱의 개인시각은 생성하지 않았습니다.'
 elif offering.startswith(('13203','13206','13210')):
  EXTRA[offering]='현재과목·분반·교수·15주계획 및 고정원교시가 대응하는 개인실기/작곡 레슨의 학교 공시 예약입니다.개인 레슨 명칭만으로 예약을 삭제하지 않았고 실제 학생별 별도 시각·교대·협의가 확정됐다고 주장하지 않습니다.원교실과 시각을 유지하며 학생은 교수의 실제개인배정/변경 안내를 확인해야 합니다.작품 녹화 제출/매일연습 점검은 과제이며 별도 매일 출석시각을 만들지 않았습니다.'
  if offering=='13206016':EXTRA[offering]+='13·14주 입시 보강은 실제날짜·시각 미확정으로 원예약에서 제외했습니다.나머지 정상일은 현재1:1대면레슨 방법을 보존했습니다.'
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3191PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
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
   meetings=[];held=list(HELD_DATES.get(offering,[]))
   for block in blocks:
    day=begin
    while day<=end:
     if day.isoweekday()==block['weekday']:
      if day.isoformat() in HOLIDAYS and offering in UNKNOWN_HOLIDAY:held.append(day.isoformat())
      if day.isoformat() not in HOLIDAYS and day.isoweekday()!=7 and not any(a<=day<=z for a,z in ranges) and day.isoformat() not in held:
       meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
       if offering=='13206016':meeting['deliveryMode']='inPerson'
       meetings.append(meeting)
     day+=dt.timedelta(days=1)
   assert meetings
   prior=copy.deepcopy(c['departmentRemarks']);auto='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
   remarks={d:'\n'.join([*(s for s in r.split('\n') if s!=auto),NOTE]) for d,r in prior.items()}
   suffix=[EXTRA.get(offering,'현재 이론·AI 실습의 정규 공시 예약 계획입니다. 온라인 도구·사이버캠퍼스 과제 제출은 수업 시각 변경을 의미하지 않습니다. 온라인퀴즈의 시험 장소가 강의실이라고 명시되면 원 예약만 보존하며 별도 시험 시각을 만들지 않았습니다.')]
   for w in omitted:suffix.append(f'현재{w["week"]}주차({w["startMonthDay"]}~{w["endMonthDay"]}) 원안내: {" / ".join(w["operatingContexts"])}. 이 범위는 실제 방식·대체평가·보강 시각 미확정으로 정규 예약 일정에서 제외했습니다. 휴강 확정과 동일시하지 않았습니다.')
   if held:suffix.append('휴강 확정이 아닌 장소/방식/시각 미확정 범위: '+', '.join(sorted(set(held)))+'. 원교실 예약을 변경된 장소 또는 미확정 방식의 실제 참석으로 강제하지 않았습니다.')
   method=report.get('teachingMethodEducationalExcerpt','')
   suffix.append('현재 교육용 수업 안내: '+method)
   remarks={d:r+'\n'+'\n'.join(suffix) for d,r in remarks.items()}
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'inPersonFromCurrentMethod' if offering=='13206016' else 'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==12
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3191
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
