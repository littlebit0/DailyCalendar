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
PREVIOUS='3166-discussion-partial-next'
REVISION='3179-academic-project-partial-v2-next'
TARGETS=set('14632001 14632004 14636001 14636002 14928001 14931001 15293012 15293013 15314008 15314016 15314020 13129075 15197002'.split())
OMIT={'14632004':[13],'14931001':[4],'15293012':[8,15],'15314008':[14],'15314020':[14],'13129075':[4,10],'15197002':[13,15]}
UNKNOWN_HOLIDAY={'15293013'}
EXTRA={
'14632001':'현재 교수 강의·학생 글 작성·동료 피드백·활동 참여의 공시 예약입니다. 실제 별도 글쓰기 제출 시각을 만들지 않았습니다.',
'14632004':'현재 교수 강의·학생 글 작성·동료 피드백 예약입니다.13주 논술고사 비대면은 실제 방식 미확정으로 원예약에서 제외했습니다.',
'14636001':'현재 남아시아 역사·종교·문화·사회 이론의 일반강의와 필요시 토론·발표 예약입니다.사진·영상·읽기 자료는 이론 이해를 위한 보조 자료로 전체영상 수업이 아닙니다.',
'14636002':'현재 남아시아 역사·종교·문화·사회 이론의 일반강의와 필요시 토론·발표 예약입니다.사진·영상·읽기 자료는 이론 이해를 위한 보조 자료로 전체영상 수업이 아닙니다.',
'14928001':'현재 교재·PPT 이론·질의응답·발표 예약입니다.세계유산 개인답사는 별도 과제로 실제 출석 수업 대체 시각을 확정한 것이 아닙니다.원15주 기말지필과2차과제제출 의무를 보존하며 허구 답사 이벤트를 만들지 않았습니다.',
'14931001':'현재 소집단 토론·성찰·발표 예약입니다.원4주 안내9/25목은 실제2026요일과 다르므로 해당 안내를 임의 날짜교정하지 않았습니다.4주 추석/보강 재안내 범위는 실제 방식 미확정으로 원예약에서 제외하고 조별활동 성적반영 의무를 보존했습니다.',
'15293012':'현재 이론·ChatGPT/Colab 실습과 과제 제출의 예약입니다.8주 중간 또는 과제 대체,15주 필기기말/16주차보강 안내는 실제 원시각 출석이 미확정이라 두 주차를 제외하고 별도 시험/보강시각을 만들지 않았습니다.',
'15293013':'현재 이론·Colab 실습·팀설계/구현/발표의 예약입니다.구글 계정/이메일·드라이브 사전준비와 첫오리엔테이션 자료 확인,중간/기말 필참 의무를 보존했습니다.휴일16주보강 원칙 또는 실시간 대체 가능성은 실제 시각 미확정으로 추가하지 않았습니다.',
'15314008':'현재 자유전공 교내 설명회·선배 정보교류·교수 강의 및 팀별토론/발표의 예약입니다.맞춤형상담 설명은 별도 학생군 전문상담 시각이 확인됐다는 의미가 아니며 그 개인 일정을 만들지 않았습니다.14주차 날짜는 게시됐지만 교육활동은 미게시라 그 원예약만 검토 중 보류했고 미게시를 휴강 확정이라고 주장하지 않았습니다.',
'15314016':'현재 자유전공 설명회·학생자료 선정·자아탐색·토론·성과발표의 공시 예약입니다.영화/음악/스포츠등은 학술문화 탐색 자료이며 실제 교외행사 배정으로 바꾸지 않았습니다.맞춤형 개인상담 별도 시각은 만들지 않았습니다.',
'15314020':'현재 전자파 문제의 팀별토론·협업 프로젝트 예약입니다.14주 지도교수 개별/그룹상담과 입시 비대면은 실제 학생군 시각·방식 미확정으로 그 주차를 제외했습니다.나머지 팀 수업을 실제1:1배정으로 바꾸지 않았습니다.',
'13129075':'현재 취·창업 교재 기반 정규예약의 부분 계획입니다.4주 택2프로그램과10주1:1상담/IAP는 학생 개별 활동 시각 미확정으로 제외했습니다.학기중 프로그램2개참여/이수증,전문컨설턴트상담·IAP온라인제출 필수이며 미이행 최소D입니다.계약학과/외국인은 사이버캠퍼스 대체이수 가능,단과별상담기간을 확인해야 합니다.원5주휴일명이 실제10/5휴일과 달라 그 명칭을 임의 수정하지 않고 학교휴업 규정의10/5만 제외했습니다.11/29는 과제제출 마감으로 별도 출석시각을 만들지 않았습니다.',
'15197002':'현재 반도체 팀 해커톤 프로젝트의 공시 예약입니다.병원진단서 대신 학교공식공결만 인정하며 미참여 대체과제는 없습니다.팀 과제 동일점수와 적극적 참여 의무를 보존했습니다.13주 입시 비대면/보강 및15주 경진대회는 실제 시각·장소 확인 중으로 그 원예약만 보류하고 별도 대회/보강시간을 만들지 않았습니다.'}
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3179PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
 for campus,source in [('global','20'),('medical','21')]:
  data=copy.deepcopy(read(f'gachon-{campus}-2026-2.published-regular-{PREVIOUS}-20261008.json'))
  for c in data['courses']:
   offering=c['courseCode']+c['section'];key=(source,offering)
   if offering not in TARGETS or c['scheduleStatus']!='unrecognized':continue
   report,base,review=reports[key],bases[key],reviews[key]
   if offering=='15314008':
    assert len(report['weeklyRows'])==15
    assert [w['week'] for w in report['weeklyRows']]==list(range(1,16))
    begin=dt.date.fromisoformat(base['period']['startDate'])
    end=dt.date.fromisoformat(base['period']['endDate'])
    for w in report['weeklyRows']:
     a,z=(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay'])
     assert a==begin+dt.timedelta(days=7*(w['week']-1))
     assert z==min(end,a+dt.timedelta(days=6))
     assert w['activityPresent']==(w['week']!=14)
   else:
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
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current15weeklydateframes,week14activityunpublishedandheld;normalpublishedreservationsonly' if offering=='15314008' else 'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'incompleteActivityWeeks':[14] if offering=='15314008' else [],'currentTeachingMethodReviewed':True,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'incompleteActivityWeeks':[14] if offering=='15314008' else [],'individualWeeklyOperationConfirmed':False,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==13
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3179
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
