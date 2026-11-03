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
PREVIOUS='3041-published-incomplete-partial-v2-next'
REVISION='3058-ai-regular-partial-next'
TARGETS=set('15506001 15879001 15879002 15291005 15291006 15291008 15291011 15291015 15291021 15291022 15291026 15292003 15292004 15292005 15293002 15293007 15293011'.split())
OMIT={'15506001':[14],'15879001':[14],'15879002':[14],'15291008':[15],'15291015':[15],'15291026':[13],'15293007':[8,15],'15293011':[8,15]}
UNKNOWN_HOLIDAY={'15506001','15291006','15291015','15291021','15292003','15292004','15293002','15293011'}
EXTRA={
'15506001':'9/24추석 온라인 대체와14주차 입시 비대면은 실제 실시간/영상 시각 배정이 미확정이며 휴강 확정으로 바꾸지 않았습니다.',
'15879001':'간단한 교내 역학 실습과 이론 예약 계획을 보존했습니다.14주차 입시에 따른 비대면 또는 보강은 날짜·방식 미확정으로 제외했습니다.',
'15879002':'간단한 교내 역학 실습과 이론 예약 계획을 보존했습니다.14주차 입시에 따른 비대면 또는 보강은 날짜·방식 미확정으로 제외했습니다.',
'15291008':'구글 계정과 드라이브가 필요합니다.15주차 기말평가의12/21월 보강 예정은 실제 시각 미확정이며 정규15주차 출석 및 별도12/21시각을 만들지 않았습니다.',
'15291015':'개인 노트북 사용은 가능하나 시험 때에는 불가합니다.15주차는 퀴즈 또는 대체보고서로 실제 정규 출석 여부가 미확정이라 해당 주차를 제외했습니다. 휴일 Zoom 또는 영상 대체는 휴강이 아닌 방식 미확정입니다.',
'15291021':'구글 계정과 이메일·드라이브를 사전에 준비해야 하고 첫 오리엔테이션 자료를 확인해야 합니다. 중간·기말은 필참입니다. 휴일은16주차 보강 원칙 또는 온라인 실시간 대체 가능성이 있으나 실제 날짜·시각은 미확정이며 추가하지 않았습니다.',
'15291026':'13주차 Python 파일처리는 비대면으로 명시되나 실제 방식과 시각이 미확정이라 해당 주차를 제외했습니다.',
'15292005':'노트북 지참, 실습 참여, LMS 과제 제출 및 학문적 정직 준수 의무를 보존했습니다. LMS 제출을 비동기 정규수업으로 둔갑시키지 않았습니다.',
'15293007':'8주차는 중간고사 또는 과제 대체,15주차는 기말 필기시험과16주차 보강 안내로 실제 참석 날짜·시각이 미확정이며 해당 주차를 제외했습니다. 별도 시험/보강 시각을 생성하지 않았습니다.',
'15293011':'8주차는 중간고사 또는 과제 대체,15주차는 기말 필기시험과16주차 보강 안내로 실제 참석 날짜·시각이 미확정이며 해당 주차를 제외했습니다. 공휴일은16주차 보강 또는 실시간 대체 가능성이 있으나 실제 날짜·시각은 미확정입니다.'}
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3058PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
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
      if day.isoformat() not in HOLIDAYS and day.isoweekday()!=7 and not any(a<=day<=z for a,z in ranges):
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
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==17
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3058
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
