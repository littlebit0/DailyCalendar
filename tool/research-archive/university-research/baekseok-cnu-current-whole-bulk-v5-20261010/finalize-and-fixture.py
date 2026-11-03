import pathlib,json,hashlib,shutil
S=pathlib.Path('work/university-research/baekseok-cnu-current-whole-bulk-v3-20261010');D=S.with_name('baekseok-cnu-current-whole-bulk-v4-20261010');D.mkdir(exist_ok=False)
for f in S.iterdir():
 if f.is_file():shutil.copyfile(f,D/f.name)
p=json.loads((D/'proof.json').read_text());selected={x['sourceId']:x for x in p['newCourses']};warn='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.';corr={}
for ds in p['datasets']:
 f=D/ds['candidate'];data=json.loads(f.read_text())
 for c in data['courses']:
  if c['sourceId']not in selected:continue
  se=c['sourceEducation'];corr[c['sourceId']]={'previousGeneratedValues':{k:se.get(k)for k in ['derivedBlockingExplanation','registrationStatus','individualReviewStatus']},'changedFields':['derivedBlockingExplanation','registrationStatus','individualReviewStatus']};assert se['derivedBlockingExplanation']==warn
  se['derivedBlockingExplanation']='학교 현재 공개 정규 수업 계획의 요일·시작/종료 시각에 따른 예약입니다. 실제 개별 출석이나 최신 운영 완료를 확정하지 않습니다.';se['registrationStatus']='ordinaryPublishedReservation';se['individualReviewStatus']='wholeStructuredCurrentOperatingContextReviewed'
 f.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(D/'previous-generated-status-archive.json').write_text(json.dumps(corr,ensure_ascii=False,indent=2)+'\n')
txt=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='work/university-research/baekseok-cnu-current-whole-bulk-v4-20261010';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
void main(){test('Baekseok own clock boundary and CNU full native HH bulk source preservation',(){
 final proof=read('proof.json')as Map,old=<String,dynamic>{},raw=<String,dynamic>{};final all=<UniversityCourse>[];
 for(final d in proof['datasets']){final a=read(d['prior']as String)as Map,b=read(d['candidate']as String)as Map;for(final c in a['courses'])old[c['sourceId']]=c;for(final c in b['courses'])raw[c['sourceId']]=c;all.addAll(UniversityDataset.fromJson(Map<String,dynamic>.from(b)).courses);}
 expect(old,hasLength(6459));expect(raw.keys.toSet(),old.keys.toSet());final ps={for(final p in proof['newCourses'])p['sourceId']:p};expect(ps,hasLength(192));final queue=read('queue.json')as List;expect(queue,hasLength(4402));expect(queue.where((q)=>q['school']=='baekseok'),hasLength(2549));for(final q in queue)expect(raw[q['sourceId']],old[q['sourceId']]);
 final archive=read('previous-full-remarks-archive.json')as Map,status=read('previous-generated-status-archive.json')as Map;var baseline=0,baseDates=0,added=0;
 for(final c in all){final before=old[c.sourceId]as Map,current=raw[c.sourceId]as Map;
 if(!ps.containsKey(c.sourceId)){expect(current,before);if((before['schedules']as List).isNotEmpty){baseline++;baseDates+=(before['schedules']as List).length;}continue;}
 final p=ps[c.sourceId]as Map;expect(p['school'],'cnu');expect(p['originalWholeObject'],before);expect(before['schedules'],isEmpty);expect(archive[c.sourceId],before['departmentRemarks']);
 for(final e in before.entries){if(!{'schedules','scheduleStatus','period','departmentRemarks','sourceEducation','currentPublicPlanEducation'}.contains(e.key))expect(current[e.key],e.value,reason:'whole school native field ${c.sourceId}/${e.key}');}
 final priorEducation=before['sourceEducation']as Map,currentEducation=current['sourceEducation']as Map;
 for(final e in priorEducation.entries){if(!{'derivedBlockingExplanation','registrationStatus','individualReviewStatus'}.contains(e.key))expect(currentEducation[e.key],e.value,reason:'source educational/native fields ${e.key}');}
 expect(status[c.sourceId]['previousGeneratedValues'],{for(final k in ['derivedBlockingExplanation','registrationStatus','individualReviewStatus'])k:priorEducation[k]});expect(currentEducation['derivedBlockingExplanation'],'학교 현재 공개 정규 수업 계획의 요일·시작/종료 시각에 따른 예약입니다. 실제 개별 출석이나 최신 운영 완료를 확정하지 않습니다.');
 const warning='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.';expect(current['departmentRemarks'],{for(final e in (before['departmentRemarks']as Map).entries)e.key:e.value.toString().replaceAll(warning,'')});
 final plan=p['wholeSourceEvidence']['wholeCurrentEducationalPlan'];expect(plan['courseId'],priorEducation['courseId']);expect(plan['verifiedOn'],'2026-10-08');expect(plan['planPresent'],true);expect(current['currentPublicPlanEducation'],{'header':plan['header'],'weeks':plan['weeks'],'sourceResponseSHA256':plan['sourceResponseSHA256'],'tokenOnlyEducationalRedaction':true});
 final native=priorEducation['originalEducationFields'];expect(native['OBJ_CORS_CD_NM'],'학사과정');expect(native['OPEN_YR'],'2026');expect(native['CLOSE_YN'],'0');expect(['혼합','원격','비대면'].contains(native['LSN_METHOD_CD_NM']),false);
 final slots=<Map<String,dynamic>>[];
 for(final b in priorEducation['actualDisplayedClocks']){final m=RegExp(r'^([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})(?:\((.*)\))?$').firstMatch(b['rawDisplayedClock']as String);expect(m,isNotNull);final start=int.parse(m![2]!)*60+int.parse(m[3]!),end=int.parse(m[4]!)*60+int.parse(m[5]!);final literal={'weekday':'월화수목금토일'.indexOf(m[1]!)+1,'startMinute':start,'endMinute':end,'classroom':m[6]??''};expect(b['weekday'],literal['weekday']);expect(b['startMinute'],start);expect(b['endMinute'],end);expect(b['location'],literal['classroom']);expect(start,lessThan(end));slots.add(literal);}
 expect(slots,p['literalSlots']);const excluded={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'};final expected=<Map<String,dynamic>>[];
 for(final b in slots){for(var d=DateTime(2026,9,1);!d.isAfter(DateTime(2026,12,18));d=d.add(const Duration(days:1))){final date=d.toIso8601String().substring(0,10);if(d.weekday==b['weekday']&&!excluded.contains(date))expected.add({...b,'date':date});}}
 expect(current['schedules'],expected);expect(current['period'],{'startDate':'2026-09-01','endDate':'2026-12-18'});expect(current['bulkCurrentReservationReview']['actualAttendanceConfirmed'],false);expect(c.campus,before['campus']);expect(c.meetings.length,expected.length);added+=expected.length;
 }
 expect(baseline,1865);expect(baseDates,BASE_DATES);expect(added,6427);final scheduled=all.where((c)=>c.meetings.isNotEmpty).toList();expect(scheduled,hasLength(2057));
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){final values=<String,TimetableSyncValue>{};for(final c in scheduled){final saved=c.toTimetable(id:c.sourceId,mode:mode);expect(saved.isValid,true);for(var i=0;i<saved.meetings.length;i++){final m=saved.meetings[i];final native=raw[c.sourceId]['schedules'][i]['deliveryMode'];final expected=native=='inPerson'?LectureMode.inPerson:native=='liveOnline'?LectureMode.liveOnline:mode;expect(saved.modeOn(m,m.teachingDate!),expected);expect(saved.period!.contains(m.teachingDate!),true);}final key=timetableCourseSyncKey(saved);expect(values.containsKey(key),false);values[key]=TimetableSyncValue({...saved.toJson(),'id':key},DateTime.utc(2026,10,10),'research');}final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))as Map<String,dynamic>).materializeClasses();expect(restored,hasLength(2057));for(final c in restored)expect(c.toJson(),values[timetableCourseSyncKey(c)]!.value);}
 });}
'''
b=sum(x['baselineScheduled']for x in p['datasets']);bd=sum(x['baselineMeetings']for x in p['datasets']);txt=txt.replace('expect(baseline,1865)',f'expect(baseline,{b})').replace('hasLength(2057)',f'hasLength({b+192})').replace('BASE_DATES',str(bd));(D/'bu_cnu_combined_fixture_test.dart.txt').write_text(txt)
(D/'HANDOFF.md').write_text(f'''# 백석·충남 현재 전체 미예약 bulk source 처리\n\n전체6459 교육 객체/미예약4594행의 구조화 자료를 처리했습니다. 백석 신규0,2549큐; 충남 신규192강좌/6427회,1853큐. 합계 기존{b} 예약강좌/{bd}회를 보존하며 신규 포함{b+192}/{bd+6427}입니다. 학교 전체 지원 완료·실제 출석·지원 불가능을 뜻하지 않습니다. SDK/제품/AGENT_MEMORY 수정0,새 네트워크0.\n\n백석의 일반 학부 native 교시는 존재하지만 자체 absolute HH가 캐시에 확인되지 않습니다. 현행계약학과20의 시각을 일반2549로 전파하지 않고 기존22예약 객체 그대로 보존했습니다. 같은 negative 자료를 재조회하지 않았습니다.\n\n충남은 자체 rawDisplayedClock의요일/HH/원문 장소를 직접 파싱하고 전체 개별 header/weeks에서 실제 원격·혼합,개별 배정·실기·임상,집중·휴강·보강,field주차,시간/학기 충돌을 큐로 유지했습니다. 학습교재·주제·발표·일반실습 방법이라는 이유만으로 정규계획 전체를 막는 blanket warning은 해소했습니다. 빈 장소와 캠퍼스unknown은 그대로입니다. 원본교육fields/전체계획/교수/학점/수강제한 보존,특정날짜 시험/보강 추정0입니다.\n\n현재 자체 학사기간9/1–12/18에 학교휴업/12/8–11 보충기간을 제외한 공개정규계획 후보입니다. 실제 새 개별 운영 완료·강의방식 확정은 주장하지 않습니다. generated sourceEducation 상태3필드만 previous-generated-status-archive.json으로 원래값을 보존하고 정정했습니다. 학교 originalEducationFields와 actualDisplayedClocks는 정확히 불변입니다.\n\n최종 fixture bu_cnu_combined_fixture_test.dart.txt 하나에 모든 객체/학교필드/정확비고 복원/자체 literal HH/기간/3모드 Drive 왕복을 준비했습니다. 아직 SDK 실행하지 않았습니다. v1/v2는 원문 장소 nested/blank표기 parser 중단 draft이며 v3는 generated경고정정전 draft, 채택본은v4입니다. 원동결 및 제품자산 쓰기0. parser.py/최종화스크립트 재실행은 금지합니다.\n''')
(D/'finalize-and-fixture.py').write_bytes(pathlib.Path(__file__).read_bytes());files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(D.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};(D/'SHA256SUMS.json').write_text(json.dumps({'files':files},ensure_ascii=False,indent=2)+'\n');print(len(files),hashlib.sha256((D/'SHA256SUMS.json').read_bytes()).hexdigest(),b,bd)
