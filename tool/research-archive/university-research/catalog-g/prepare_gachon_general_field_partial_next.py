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
PREVIOUS='3058-ai-regular-partial-next'
REVISION='3077-general-field-partial-next'
TARGETS=set('15559001 15559002 15560001 15676001 15739001 15994001 16005001 16021001 16025001 16025002 16028001 16029001 16029002 15979015 15979038 15979045 15629001 15652001 15742001'.split())
OMIT={'15559001':[7,8],'15559002':[7,8],'15676001':[4],'15739001':[3],'15994001':[14],'16025001':[8,15],'16025002':[8,15],'15652001':[14],'15742001':[4,8,9,10,11,12,13,14,15]}
UNKNOWN_HOLIDAY={}
EXTRA={
'15559001':'건축 답사는 방법 안내7주차와 주차표8주차가 서로 달라 두 범위를 모두 미확정으로 보류했습니다. 보고서 제출의 별도 현장 시각을 만들지 않았고 나머지 공간이론·조별 토론 예약 계획은 보존했습니다.',
'15559002':'건축 답사는 방법 안내7주차와 주차표8주차가 서로 달라 두 범위를 모두 미확정으로 보류했습니다. 보고서 제출의 별도 현장 시각을 만들지 않았고 나머지 공간이론·조별 토론 예약 계획은 보존했습니다.',
'15560001':'14주차 입시 기간은 실시간 비대면으로 명시되어 실제12/1화10:00~12:50원예약의 모드만 실시간으로 보존했습니다. 영상 매체 활용은 일반 이론 수업의 보조 자료입니다.',
'15676001':'4주차 YouTube영상 온라인 수업은 정규 시각 영상 출석으로 만들지 않았습니다. 나머지 현재 이론·질문·토론의 공시 예약 계획은 보존했습니다.',
'15739001':'현재 영어 수업의3주차9/15는 코코네스쿨 투어로 원AI관305실과 다르므로 해당 원교실 예약을 제외했습니다. 나머지 현행 화요일 이론·토론·발표 예약을 보존하며 초청 특강을 학생 현장 이동으로 바꾸지 않았습니다.',
'15994001':'로봇 이론과 교내 C언어 제어 실습의 정규예약 계획입니다.14주차 입시 온라인은 실제 방식 미확정이므로 해당 주차를 제외했습니다.',
'16005001':'사전 자료 읽기와 PPT·영상 자료 활용은 강의실 질문·토론의 준비 활동입니다.9/24Zoom보강 예정은 추후 협의로 실제 날짜·시각을 추가하지 않았습니다. 외국인반 제한은 원문에 보존됩니다.',
'16021001':'여성·문화·정치적 메시지는 자화상 학습 주제이며 실제 정치행사나 변경 수업 시각을 의미하지 않습니다. 교수 강의와 학생 토론의 공시 예약을 보존했습니다.',
'16025001':'매주 앉은 자리에서3~4명 토의를 구성하고 한 학기에1회1~2분 발표합니다. 이를 시간표 배정 변경으로 둔갑시키지 않았습니다.8주차 사이버캠퍼스 퀴즈의 실제 참석 방식 미확정과15주차 리포트 제출 종강은 정규 예약에서 제외했습니다.12주차 대면vs비대면은 토론 논제입니다.',
'16025002':'매주 앉은 자리에서3~4명 토의를 구성하고 한 학기에1회1~2분 발표합니다. 이를 시간표 배정 변경으로 둔갑시키지 않았습니다.8주차 사이버캠퍼스 퀴즈의 실제 참석 방식 미확정과15주차 리포트 제출 종강은 정규 예약에서 제외했습니다.12주차 대면vs비대면은 토론 논제입니다.',
'16028001':'교내 디자인 이론·실무 사례·프로젝트 실습·발표의 공시 예약 계획입니다. 실무 사례와 실험실습/현장학습 범주명만으로 학생 교외 이동을 만들지 않았습니다.',
'16029001':'현재 전문강사 문제풀이 강의의 정규예약 계획입니다. 추가 취업 비교과 프로그램1회 이상 참여 확인서 또는 대학원 랩페어 참여가 핵심과제이며, 미이수 또는 기말 미응시 NP입니다. 비교과 참여는 별도 활동으로 시각 미확정이며 정규 강의 대체라고 주장하지 않았습니다.',
'16029002':'현재 전문강사 문제풀이 강의의 정규예약 계획입니다. 추가 취업 비교과 프로그램1회 이상 참여 확인서 또는 대학원 랩페어 참여가 핵심과제이며, 미이수 또는 기말 미응시 NP입니다. 비교과 참여는 별도 활동으로 시각 미확정이며 정규 강의 대체라고 주장하지 않았습니다.',
'15629001':'원화2교시는 문법, 금2·3교시는 복습·본문 읽기·말하기·쓰기입니다. 원복수 교실 표기는 임의 요일별 배정으로 바꾸지 않았습니다.9/25와10/9Zoom보강은 추후 협의 예정으로 실제 날짜·시각을 추가하지 않았습니다.',
'15652001':'현재 이론·토론·발표 및 매주 교내 실습의 공시 예약 계획입니다.14주차 비대면은 실제 방식 미확정으로 해당 주차를 제외했습니다.',
'15742001':'현재1~7주차 교재 발제·토론·전문가 특강 중4주차9/21~22페스타는 원목요일 예약과 다른 날이라 보류했습니다.8주차 이후는 팀별 현장답사·심층리포트의 실제 장소·개별 시각 미확정 범위로 보류한 부분계획입니다. 학기 전체 출석을 확정한 것이 아닙니다.'}
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3077PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
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
       meeting={k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']}
       if offering=='15560001' and day.isoformat()=='2026-12-01':meeting['deliveryMode']='liveOnline'
       meetings.append(meeting)
     day+=dt.timedelta(days=1)
   assert meetings
   prior=copy.deepcopy(c['departmentRemarks']);auto='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
   remarks={d:'\n'.join([*(s for s in r.split('\n') if s!=auto),NOTE]) for d,r in prior.items()}
   suffix=[EXTRA.get(offering,'현재 글쓰기 윤리·생성형AI 기록·발표·토론의 정규 공시 예약 계획입니다. 실제10/5공휴일은 학교 휴업 규정에 따라 제외했고 별도 보강 시각을 만들지 않았습니다.')]
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
 assert len(audit['promoted'])==19
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3077
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
