from pathlib import Path
import json,re,hashlib,datetime as dt
P=Path('work/university-research/catalog-t/hufs-bulk-native-operation-v15-20261010');proof=json.load(open(P/'proof.json'));expected={}
for p in proof['proofs']:
 # Independent day-first traversal of literal date scope/source weekdays, not candidate schedule arrays.
 vals=[];d=dt.date(2026,9,1)
 while d<=dt.date(2026,12,7):
  if d.isoformat()in p['allowedDateWeekLiteral']:
   for f in p['nativeFixedSlots']:
    if f['weekday']==d.isoweekday():vals.append({'date':d.isoformat(),**f})
  d+=dt.timedelta(days=1)
 assert vals==p['expectedMeetings'];expected[p['sourceId']]=vals
(P/'source-literal-independent-expectations.json').write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n')
s=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='__DIR__';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
const removedWarning=' · 공개 운영 일정 확인 중: 자동 시간 생성 보류';
const newNote='현재 2026-2 학교 자체 정규 교시·캠퍼스·개설 강좌 원문과 공개 운영 필드를 대조한 부분만 예약합니다. 학교 원문 날짜가 있으면 그 날짜를 우선하며, 휴일·평가·보강·원격·개별 배정·운영 미확정 부분은 별도 원문 큐에 보존합니다. 강의계획 미게시 자체만으로 공개 정규 개설 시각을 삭제하지 않으며, 실제 출석 및 대학 전체 최신 변경 확인 완료를 뜻하지 않습니다.';
void main(){test('HUFS entire held source classification preserves whole metadata and own clock/date boundaries with all-three-mode Drive',(){
 final old=<String,dynamic>{},raw=<String,dynamic>{};final courses=<UniversityCourse>[];
 for(final campus in ['seoul','global']){
  final before=read('hufs-$campus-baseline-whole.json') as Map;
  final now=read('hufs-$campus-2026-2.bulk-v15.json') as Map;
  for(final c in before['courses']){old[c['sourceId']]=c;}
  for(final c in now['courses']){raw[c['sourceId']]=c;}
  courses.addAll(UniversityDataset.fromJson(Map<String,dynamic>.from(now)).courses);
 }
 final proof=read('proof.json') as Map;final expected=read('source-literal-independent-expectations.json') as Map;
 final archive=read('full-previous-note-archive.json') as Map;final queue=read('queue.json') as List;
 final proofs={for(final p in proof['proofs'])p['sourceId']:p};
 expect(old,hasLength(3372));expect(raw.keys.toSet(),old.keys.toSet());expect(expected,hasLength(652));expect(queue,hasLength(239));
 expect((proof['summary'] as Map)['heldNativeProcessed'],891);expect((proof['summary'] as Map)['heldWithParsableNativeClock'],865);
 for(final q in queue){expect(raw[q['sourceId']],old[q['sourceId']],reason:'actual source unresolved whole preservation');}
 var baseCount=0,baseDates=0,added=0;
 for(final c in courses){
  final before=old[c.sourceId] as Map;
  if(!expected.containsKey(c.sourceId)){
   expect(raw[c.sourceId],before,reason:'all unchanged fields ${c.sourceId}');
   if((before['schedules'] as List).isNotEmpty){baseCount++;baseDates+=(before['schedules'] as List).length;}continue;
  }
  expect(before['schedules'],isEmpty);final p=proofs[c.sourceId] as Map;
  expect(p['previousWholeObject'],before);expect(archive[c.sourceId],before['departmentRemarks']);
  for(final e in before.entries){if(!{'schedules','scheduleStatus','sourcePartialCoverage','departmentRemarks','semanticOperatingReview'}.contains(e.key)){expect(raw[c.sourceId][e.key],e.value,reason:'original university field ${c.sourceId}/${e.key}');}}
  for(final e in (before['departmentRemarks'] as Map).entries){expect(raw[c.sourceId]['departmentRemarks'][e.key],(e.value as String).replaceAll(removedWarning,'')+'\n'+newNote);}
  expect((raw[c.sourceId]['schedules'] as List).map((m)=>jsonEncode(m)).toList(),(expected[c.sourceId] as List).map((m)=>jsonEncode(m)).toList());
  final plan=p['wholePlan'] as Map;expect(plan['key'],c.courseCode+before['section']);expect(plan['campus'],before['campus']=='seoul'?'H1':'H2');
  final planFile=jsonDecode(File(p['planFile'] as String).readAsStringSync());expect(planFile,plan);
  for(final rr in p['wholeRawOfferings']){
   expect(rr['row']['lssnCd'],plan['key']);expect(rr['row']['ledgYear'],'2026');expect(rr['row']['ledgSessn'],'3');expect(rr['row']['orgSect'],'A');expect(rr['row']['campus'],plan['campus']);
  }
  for(final m in c.meetings){
   expect(m.teachingDate!.weekday,m.weekday);expect(m.teachingDate!.isBefore(DateTime(2026,9,1)),false);expect(m.teachingDate!.isAfter(DateTime(2026,12,7)),false);
   final fixed=(p['nativeFixedSlots'] as List).singleWhere((h)=>h['weekday']==m.weekday&&h['startMinute']==m.originalStartMinute&&h['endMinute']==m.originalEndMinute&&h['classroom']==m.classroom);
   expect(fixed['startMinute'],m.originalStartMinute);expect(fixed['endMinute'],m.originalEndMinute);
  }
  expect((raw[c.sourceId]['schedules'] as List).every((m)=>m['deliveryMode']==null),true);added+=c.meetings.length;
 }
 expect(baseCount,2481);expect(baseDates,35802);expect(added,7867);expect(courses.where((c)=>c.meetings.isNotEmpty),hasLength(3133));
 final discrete=raw['hufs/global/2026/2/M012111/01'];
 expect(discrete['sourceSchedule'],'금 4 5 6 (0301)');expect((discrete['schedules'] as List).map((m)=>m['date']).toList(),['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-30','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04']);
 expect((discrete['schedules'] as List).every((m)=>m['startMinute']==720&&m['endMinute']==890&&m['classroom']=='0301'),true);
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){
  final values=<String,TimetableSyncValue>{};
  for(final c in courses.where((c)=>c.meetings.isNotEmpty)){
   final saved=c.toTimetable(id:c.sourceId,mode:mode);expect(saved.isValid,true);
   for(var i=0;i<saved.meetings.length;i++){
    final m=saved.meetings[i];final native=raw[c.sourceId]['schedules'][i]['deliveryMode'];final expectedMode=native=='inPerson'?LectureMode.inPerson:native=='liveOnline'?LectureMode.liveOnline:mode;
    expect(saved.modeOn(m,m.teachingDate!),expectedMode);expect(saved.period!.contains(m.teachingDate!),true);
   }
   final key=timetableCourseSyncKey(saved);expect(values.containsKey(key),false);values[key]=TimetableSyncValue({...saved.toJson(),'id':key},DateTime.utc(2026,10,10),'research');
  }
  final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String,dynamic>).materializeClasses();
  expect(restored,hasLength(3133));for(final c in restored){expect(c.toJson(),values[timetableCourseSyncKey(c)]!.value);}
 }
});}
'''.replace('__DIR__',str(P))
# Actual UniversityCourse exposes code, not presumed getter; use raw original code in identity assertion.
s=s.replace("c.courseCode+before['section']","(before['courseCode'] as String)+(before['section'] as String)")
(P/'hufs_bulk_final_fixture_test.dart.txt').write_text(s)
(P/'HANDOFF.md').write_text('''# 외대 전체 미예약 자료 일괄 처리 source-only

현재 자산 3,372개 전체 원본과 v14 예약 2,481강좌/35,802회를 보존합니다. 미예약 891행을 모두 일괄 분류했습니다. 자체 교시 파싱 가능865행, 무시각23행과 미공표13교시3행 등 파싱 불가26행입니다. 요청의868 숫자와 현재 파싱 가능 정의는 다릅니다.

신규 후보652강좌/7,867회, 누적3,133강좌/43,669회. 날짜 명시116강좌는 자체 날짜와 실제 native요일·교시가 일치하는 그룹만, 나머지536강좌는 자체 현재 개설/정규 기간과 해당 주차의 미확정/원격/평가/보강 제외 규칙으로 처리했습니다. 그중 실제 강의계획 미게시41개는 미게시 자체만으로 현재 공개 정규 개설 시각을 버리지 않습니다. 실제 원자료 원격/집중 플래그나 학교 운영 문구가 있으면 이 예외를 적용하지 않습니다.

불확정 큐239행은 전체 학교 교육 필드와 원자료/계획을 보존합니다. 지도교수 협의·비대면·시각 미확정·학교 원문 시간 충돌·날짜별 분배 미확정은 후보로 만들지 않습니다. 알려진 실제 HH13 미공표를 정각 일반 규칙으로 추정하지 않습니다. 각 캠퍼스 자기 편람의 0–12 또는1–12 교시 표만 사용했습니다. 원문 이수구분·소속·분반·비고·모든 기존 수업 객체 손실0.

M012111-01 이산수학은 실제 현재 계획의 9/4,9/11,9/18,10/2,10/16,10/30,11/6,11/13,11/20,11/27,12/4 11회만 12:00–14:50/0301로 후보화했습니다. Oct23 시험,12/8 요일 충돌 보강,12/11 기간 외 보강,12/18 시험은 원문 큐에 보존합니다. 중간고사 해설은 정규 교수 내용으로 분리했습니다.

정확 연구 생성 ‘공개 운영 일정 확인 중’ 문구만 제거했으며 제거 전 전체 비고를 full-previous-note-archive.json에 보존합니다. 학교 문구 삭제0. 실제 강좌 운영전체 최신/폐강/출석 완료 주장은 없습니다. 데이터 처리 결과와 실제 SDK 검증 완료를 구분하며 source-only fixture 하나만 준비했습니다. SDK·제품·AGENT_MEMORY 수정0.
''')
(P/'fixture-freeze.py').write_text(Path(__file__).read_text());files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(P.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};(P/'SHA256SUMS.json').write_text(json.dumps({'files':files,'SDKExecutions':0,'productWrites':0,'completionClaim':False},ensure_ascii=False,indent=2)+'\n');print(len(files),hashlib.sha256((P/'SHA256SUMS.json').read_bytes()).hexdigest())
