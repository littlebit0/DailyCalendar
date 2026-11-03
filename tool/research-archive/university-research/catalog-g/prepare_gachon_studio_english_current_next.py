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
PREVIOUS='3134-medical-current-radiography-next'
REVISION='3150-studio-english-current-next'
TARGETS=set('08386009 08386022 08386025 08388021 12705001 12705007 15217002 13527001 13528001 13528002'.split())|{f'13109{i:03}' for i in range(1,7)}
OMIT={'12705001':[14],'12705007':[14],'13528001':[13],'13528002':[14]}
UNKNOWN_HOLIDAY={}
HELD_DATES={f'13109{i:03}':['2026-10-22'] for i in range(1,7)}
EXTRA={
'08386009':'현재 물리학 이론·토론/실험의 정규 공시 예약이며 플립러닝이라는 이름만으로 전체영상 출석을 만들지 않았습니다. 원복수 실험/이론 강의실 표기는 임의 교시별 배정으로 분리하지 않았습니다. 실제 방식은 학생 선택을 존중합니다.',
'08386022':'현재 이론강의·실험실습·토론의 정규 공시 예약입니다. 원복수 교실은 임의 교시별 배정으로 분리하지 않았으며 공학인증/플립러닝 원표기를 보존했습니다. 별도 실제 영상 시각은 만들지 않았습니다.',
'08386025':'현재 이론강의·실험실습·토론의 정규 공시 예약입니다. 원복수 교실은 임의 교시별 배정으로 분리하지 않았으며 공학인증/플립러닝 원표기를 보존했습니다. 별도 실제 영상 시각은 만들지 않았습니다.',
'08388021':'현재 화학 이론·실험의 공시 예약입니다.11.1~11.4등은 교재 장/절 범위이며11:00등 시간표 교시가 아닙니다. 원복수 교실을 임의 교시별로 할당하지 않았습니다.',
'12705001':'현재 자료·판서 강의의 공시 예약입니다.14주 입시 비대면 보강은 실제 방식·날짜/시각 미확정으로 원예약에서 제외했습니다.',
'12705007':'현재 S분반 자료·판서 강의의 공시 예약입니다.14주 입시 비대면 보강은 실제 방식·날짜/시각 미확정으로 원예약에서 제외했습니다.',
'15217002':'교내 작품 주제·실습·발표의 공시 예약입니다.과제1개당 최소3주는 프로젝트 소요 기간이며3주 집중학기라는 의미가 아닙니다. 카피작/무성의한 작품 평가 제외 의무를 보존했습니다.',
'13527001':'영어로 준비·읽기·토론·조별 참여해야 하며 중간과 기말을 모두 응시·제출해야 통과합니다.7주 midterm은 두 번째 수업시간의 필기시험이며 별도 시험 이벤트를 만들지 않고 원금요일09:00~10:50예약을 보존했습니다.15주 기말은 교실 에세이입니다.추석/한글날 보강은 추후 공지로 시각을 만들지 않았습니다.',
'13528001':'영어로 진행하는15주 발표 수업이며 대부분의 발표 준비는 수업 밖에서 합니다.중간/기말은 학생 발표이고 필기시험은 없습니다.6주Video Plan은 발표 준비 과제이며 전체 영상수업이 아닙니다.13주 입시 Possible Online Makeup은 실제 방식/날짜 미확정으로 보류했고 휴일 보강 시각을 만들지 않았습니다.',
'13528002':'국제대학 영어 발표 수업이며 대부분의 발표 준비는 수업 밖에서 합니다.중간/기말은 학생 발표이고 필기시험은 없습니다.6주Video Plan은 발표 준비 과제이며 전체 영상수업이 아닙니다.14주 입시 Possible Online Makeup은 실제 방식/날짜 미확정으로 보류했습니다.'}
for offering in HELD_DATES:
 EXTRA[offering]='현재 매수업 Desk Critic·공개 Presentation의 설계스튜디오 원월/목 예약을 보존합니다.판넬1600mm×850mm은 과제 크기이며 시각이 아닙니다.10/22공간사례답사 예정은 실제 목적지/학생군시각 미확정으로 해당 목요일만 제외하고10/26월 정상스튜디오 예약은 보존했습니다.10/19·12/7분반교차 평가는 원정규예약 계획이며 실제 교차발표실 배정이 확정됐다는 의미가 아닙니다.원교실을 유지하고 학생은 실제 당일 장소를 확인해야 합니다.9/24·10/5반별보강은 미확정으로 추가하지 않았습니다.'
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3150PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
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
       meetings.append({k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']})
     day+=dt.timedelta(days=1)
   assert meetings
   prior=copy.deepcopy(c['departmentRemarks']);auto='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
   remarks={d:'\n'.join([*(s for s in r.split('\n') if s!=auto),NOTE]) for d,r in prior.items()}
   suffix=[EXTRA.get(offering,'현재 이론·AI 실습의 정규 공시 예약 계획입니다. 온라인 도구·사이버캠퍼스 과제 제출은 수업 시각 변경을 의미하지 않습니다. 온라인퀴즈의 시험 장소가 강의실이라고 명시되면 원 예약만 보존하며 별도 시험 시각을 만들지 않았습니다.')]
   for w in omitted:suffix.append(f'현재{w["week"]}주차({w["startMonthDay"]}~{w["endMonthDay"]}) 원안내: {" / ".join(w["operatingContexts"])}. 이 범위는 실제 방식·대체평가·보강 시각 미확정으로 정규 예약 일정에서 제외했습니다. 휴강 확정과 동일시하지 않았습니다.')
   if held:suffix.append('휴강 확정이 아닌 현장 배정 미확정 범위: '+', '.join(sorted(set(held)))+'. 원교실 예약을 실제 교외 참석으로 강제하지 않았습니다.')
   method=report.get('teachingMethodEducationalExcerpt','')
   suffix.append('현재 교육용 수업 안내: '+method)
   remarks={d:r+'\n'+'\n'.join(suffix) for d,r in remarks.items()}
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==16
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3150
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
