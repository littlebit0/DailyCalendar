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
PREVIOUS='3150-studio-english-current-next'
REVISION='3166-discussion-partial-next'
TARGETS=set('13534006 13534011 13534012 13534013 13534014 13786001 14308009 14308015 14309001 14626001 14626002 14626006 14627001 14629003 14631001 14631002'.split())
OMIT={'13534011':[4],'13534012':[4],'13534013':[4],'13534014':[4],'14308015':[4],'14626001':[5,13],'14626002':[5,13],'14626006':[4,6],'14627001':[4,8],'14629003':[13],'14631001':[4],'14631002':[4]}
UNKNOWN_HOLIDAY={}
EXTRA={
'13786001':'현재 공기업 전문강사 문제풀이의 공시 예약입니다.추가 취업 비교과 프로그램1회이상 참여확인서 또는 대학원 랩페어 참여가 핵심과제이며 미이수/기말 미응시 NP입니다.이를 정규 강의 대체 시각으로 바꾸지 않았습니다.',
'14308009':'외국인반의 교수 강의·학생 발표·토의 예약입니다.추석 보강은 일정 논의 예정으로 별도 날짜·시각을 만들지 않았습니다.',
'14308015':'외국인반의 강의·토론·토의 예약입니다.4주 추석 온라인수업 퀴즈는 실제 참석 방식·시각 미확정으로 그 범위를 정규 예약에서 제외했습니다.',
'14309001':'교수/학생 시사 문제 공유·토론의 예약입니다.기사의 선진국보다1시간 덜 잔다 문구는 수면통계 학습 주제이며 강의시간1시간 단축이 아닙니다.외국인반 원제한을 보존했습니다.',
'14626001':'정규 강의·텍스트 독해·글쓰기·토론 예약입니다.5/13주 동영상 대체 예정은 원시각 출석을 확정하지 않고 해당 범위를 제외했습니다.사이버캠퍼스 교안 공지는 강의 전체가 비동기라는 뜻이 아닙니다.',
'14626002':'정규 강의·텍스트 독해·글쓰기·토론 예약입니다.5/13주 동영상 대체 예정은 원시각 출석을 확정하지 않고 해당 범위를 제외했습니다.사이버캠퍼스 교안 공지는 강의 전체가 비동기라는 뜻이 아닙니다.',
'14626006':'정규 강의·텍스트 독해·글쓰기·토론 예약입니다.4/6주 동영상 대체 예정은 원시각 출석을 확정하지 않고 해당 범위를 제외했습니다.',
'14627001':'명저 읽기·개인 활동지·조별토론·발표의 예약입니다.4주 추석 온라인활동과8주 개별종합과제는 실제 원시각 참석 확인이 아니므로 그 범위를 제외했습니다.15주 종합평가의 별도시험시각은 만들지 않았습니다.',
'14629003':'현재 방법은 대면수업이며 결석자가 녹화강의를 자율이수 후 차기 수업에 참석하도록 권장합니다.녹화는 전체 정규수업의 영상 대체가 아닙니다.13주 입시 Zoom가능성은 실제 운영 미확정으로 제외하고 나머지 원예약 대면 모드를 보존했습니다.실라부스 내용 순서 변경을 임의 수업 날짜 변경으로 만들지 않았습니다.',
'14631001':'현재 강의·발표·댓글·팀활동의 정규 공시 예약입니다.4주 독립서점 현장 방문/관찰/체험 및 인증사진·보고서는 실제교외배정 시각 미확정으로 그 원교실 예약에서 제외했습니다.별도 서점 일정은 만들지 않았습니다.',
'14631002':'현재 강의·발표·댓글·팀활동의 정규 공시 예약입니다.4주 독립서점 현장 방문/관찰/체험 및 인증사진·보고서는 실제교외배정 시각 미확정으로 그 원교실 예약에서 제외했습니다.별도 서점 일정은 만들지 않았습니다.'}
for offering in TARGETS:
 if offering.startswith('13534'):
  EXTRA[offering]='현재15주 영어 교과목·분반·교수·학기 및 정규예약이 일치합니다.방법의 상세 정보는 첫 주 교수자가 제공한다고 명시되어 실제 강의방식 전체 확인이나 대면 확정을 주장하지 않습니다.학생은 실제 방식과 교수 공지를 확인해야 합니다.14/15주 필기/말하기 기말평가의 별도시험시각을 만들지 않고 공시예약만 보존했습니다.'
def read(n):return json.loads((ROOT/n).read_text())
def main():
 reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read('gachon-full-operating-report-audit.json')['reports']}
 reviews={(r['campus'],r['officialOfferingCode']):r for r in read('gachon-full-operating-semantic-review.json')['rows']}
 bases={(r['campusSourceCode'],r['officialOfferingCode']):r for r in read('gachon-full-normalized-source-candidates.json')['courses']}
 audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'productionProjectionPermitted':'validated3166PublishedPlansOnly','previousManifest':f'gachon-published-regular-{PREVIOUS}-sha-manifest-20261008.json','excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'reviewPolicy':'School-published regular reservation plans, not attendance; exact weekly remote/replacement/changed assessment scopes held. Virtual coding and LMS submissions alone do not replace class reservations.'}
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
       if offering=='14629003':meeting['deliveryMode']='inPerson'
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
   c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'inPersonFromCurrentMethod' if offering=='14629003' else 'unknownUserSelectionRequired' if not base.get('deliveryMode') else base['deliveryMode'],'sourceCampusExplicit':source,'dateProof':'Current complete weekly plan and school published regular reservation; actual uncertain delivery and replacement weeks excluded.','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','individualWeeklyOperationConfirmed':False,'publishedWeeklyRowCount':15,'currentTeachingMethodReviewed':True,'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held))})
   audit['promoted'].append({'sourceId':c['sourceId'],'offering':offering,'campus':campus,'previousReason':review['decision'],'currentTeachingMethod':method,'weeklyOperatingContexts':[s for w in report['weeklyRows'] for s in w['operatingContexts']],'originalClockBlocks':blocks,'period':c['period'],'omittedUnresolvedAssessmentWeeks':omitted,'heldDateScope':sorted(set(held)),'datedMeetingCount':len(meetings),'publishedWeeklyRowCount':15,'individualWeeklyOperationConfirmed':False,'generatedUncertaintyRemovedOnly':auto,'sourceEnrollmentEvidence':review['enrollmentReview']})
  data['currentFullOperatingAuditFinished']=False
  name=f'gachon-{campus}-2026-2.published-regular-{REVISION}-20261008.json';out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
  audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
 assert len(audit['promoted'])==16
 audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==3166
 audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
 for kind,content in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
  out=ROOT/f'gachon-published-regular-{REVISION}-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(audit['datasets'],ensure_ascii=False))
if __name__=='__main__':main()
