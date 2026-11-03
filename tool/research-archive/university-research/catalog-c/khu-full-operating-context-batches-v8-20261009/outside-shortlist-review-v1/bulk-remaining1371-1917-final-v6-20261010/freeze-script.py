from pathlib import Path
import json,hashlib
P=Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/bulk-remaining1371-1917-final-v5-20261010')
s=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
const dir = '__DIR__';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
const oldWarning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.';
const oldOnline='현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.';
const physicalNote='현재 2026-2 원문 자체 명시 대면 운영·절대 수업시각·교수·캠퍼스·주차 기간이 일치하는 정규 전체 수업 그룹만 부분 예약합니다. 원격·혼합·개별 배정·평가·보강·운영 미확정 그룹은 예약하지 않고 원문과 별도 큐에 보존합니다. 사용자 강의 방식과 기존 개인 데이터는 유지하며, 실제 출석 또는 대학 전체 변경 확인 완료를 뜻하지 않습니다.';
const liveNote='현재 2026-2 개별 원문의 명시 실시간 온라인 운영과 동일 강좌·교수·캠퍼스·주차 및 절대 수업시각이 일치한 정규 수업 전체 그룹만 부분 예약합니다. 평가·보강·기간 및 방식 미확정 그룹은 원문에 보존하고 예약하지 않습니다. 기존 개인 데이터와 원문 강의실은 유지하며 실제 출석 또는 대학 전체 최신 변경 확인 완료를 뜻하지 않습니다.';
void main(){test('KHU final bulk whole-source boundary, independent calendar, whole preservation, all three mode Drive roundtrip',(){
 final old=<String,dynamic>{},raw=<String,dynamic>{};final courses=<UniversityCourse>[];
 for(final campus in ['seoul','global']){
  final previous=read('prior-$campus-whole.json') as Map;
  final current=read('khu-$campus-2026-2.bulk-remaining-prepared.json') as Map;
  for(final c in previous['courses']){old[c['sourceId']]=c;}
  for(final c in current['courses']){raw[c['sourceId']]=c;}
  courses.addAll(UniversityDataset.fromJson(Map<String,dynamic>.from(current)).courses);
 }
 final expected=read('literal-source-independent-expectations.json') as Map;
 final proof=read('bulk-independent-proof.json') as Map;
 final archive=read('previous-full-remarks-archive.json') as Map;
 expect(old,hasLength(4666));expect(raw.keys.toSet(),old.keys.toSet());expect(expected,hasLength(63));
 expect(proof['processedNative'],547);expect(read('whole-source-range.json'),hasLength(547));
 final queue=read('uncertain-operating-queue.json') as List;expect(queue,hasLength(484));
 for(final q in queue){expect(raw[q['sourceId']],old[q['sourceId']],reason:'unresolved whole object ${q['ordinal']}');}
 final proofById={for(final p in proof['proofs'])p['sourceId']:p};
 var oldCount=0,oldDates=0,added=0;
 for(final c in courses){
  final before=old[c.sourceId] as Map;
  if(!expected.containsKey(c.sourceId)){
   expect(raw[c.sourceId],before,reason:'all unselected fields ${c.sourceId}');
   if((before['schedules'] as List).isNotEmpty){oldCount++;oldDates+=(before['schedules'] as List).length;}
   continue;
  }
  expect(before['schedules'],isEmpty);
  final p=proofById[c.sourceId] as Map;final isLive=p['mode']=='explicit_liveOnline';
  expect(p['originalWholeObject']['sourceId'],c.sourceId);
  for(final e in before.entries){if(!{'schedules','scheduleStatus','departmentRemarks','semanticOperatingReview'}.contains(e.key)){expect(raw[c.sourceId][e.key],e.value,reason:'original native field ${c.sourceId}/${e.key}');}}
  expect(archive[c.sourceId],before['departmentRemarks']);
  for(final e in (before['departmentRemarks'] as Map).entries){
   final remaining=(e.value as String).replaceAll('$oldWarning\n','').replaceAll(oldWarning,'').replaceAll(oldOnline,'');
   expect(raw[c.sourceId]['departmentRemarks'][e.key],remaining+'\n'+(isLive?liveNote:physicalNote));
  }
  final actual=(raw[c.sourceId]['schedules'] as List).map((m)=>jsonEncode(m)).toSet();
  final sourceExpected=(expected[c.sourceId] as List).map((m)=>jsonEncode(m)).toSet();
  expect(actual,sourceExpected);expect(actual.length,(expected[c.sourceId] as List).length);
  final sourcePlan=p['wholeEducationPlan'] as Map;
  expect(sourcePlan['header'],['2026학년도 2학기 강의계획서']);expect(sourcePlan['campus'],before['campus']=='global'?'국제':'서울');
  expect(sourcePlan['lectureCode'],before['sourceEducationalVariants'][0]['lecture_cd']);
  final sections=sourcePlan['educationalSections'] as List;
  final rows=sections.singleWhere((s)=>s['section']=='주별강의내용')['rows'] as List;
  final allowed=(p['allowedWeeksLiteral'] as List).cast<int>();
  for(final m in c.meetings){
   final day=m.teachingDate!;final week=day.difference(DateTime(2026,9,1)).inDays~/7+1;expect(allowed,contains(week));
   final row=rows.singleWhere((r)=>r[0]=='${week}주');final span=RegExp(r'^(\d+)/(\d+)\s*~\s*(\d+)/(\d+)$').firstMatch(row[1] as String)!;
   final a=DateTime(2026,int.parse(span[1]!),int.parse(span[2]!));final b=DateTime(2026,int.parse(span[3]!),int.parse(span[4]!));
   expect(day.isBefore(a)||day.isAfter(b),false);expect(day.weekday,m.weekday);
   expect(m.originalStartMinute,m.startMinute);expect(m.originalEndMinute,greaterThan(m.originalStartMinute));
  }
  added+=c.meetings.length;
 }
 expect(oldCount,3095);expect(oldDates,57858);expect(added,1076);
 expect(courses.where((c)=>c.meetings.isNotEmpty),hasLength(3158));
 // CHE33405 Nov30 is an actual own week13 experiment; prior045 forbidden expectation was wrong.
 final che=raw['khu/2026/2/global/CHE33405'];
 expect(che,old['khu/2026/2/global/CHE33405']);
 expect((che['schedules'] as List).singleWhere((m)=>m['date']=='2026-11-30'),{'date':'2026-11-30','weekday':1,'startMinute':990,'endMinute':1280,'classroom':'실124호'});
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){
  final values=<String,TimetableSyncValue>{};
  for(final c in courses.where((c)=>c.meetings.isNotEmpty)){
   final saved=c.toTimetable(id:c.sourceId,mode:mode);expect(saved.isValid,true);
   for(var i=0;i<saved.meetings.length;i++){
    final m=saved.meetings[i];final published=raw[c.sourceId]['schedules'][i]['deliveryMode'];
    final expectedMode=published=='inPerson'?LectureMode.inPerson:published=='liveOnline'?LectureMode.liveOnline:mode;
    expect(saved.modeOn(m,m.teachingDate!),expectedMode);expect(saved.period!.contains(m.teachingDate!),true);
   }
   final key=timetableCourseSyncKey(saved);expect(values.containsKey(key),false);
   values[key]=TimetableSyncValue({...saved.toJson(),'id':key},DateTime.utc(2026,10,10),'research');
  }
  final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);
  final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String,dynamic>).materializeClasses();
  expect(restored,hasLength(3158));for(final c in restored){expect(c.toJson(),values[timetableCourseSyncKey(c)]!.value);}
 }
});}
'''.replace('__DIR__',str(P))
# Original unrounded end preserved. Model display rounding means startMinute may be adjusted, so only original minutes are source checked.
s=s.replace('expect(m.originalStartMinute,m.startMinute);','')
(P/'khu_final_bulk_fixture_test.dart.txt').write_text(s)
(P/'HANDOFF.md').write_text('''# KHU 남은 자료 일괄 처리 source-only 인계

- 기준: 동결 047 누적 4,666개 전체 객체, 시간표 예약 후보 3,095강좌/57,858회. 제품·SDK 실행 0.
- 1371–1917의 전체 교육 JSON 547개를 보수 조건으로 일괄 처리했습니다. 개별 사람식 전수 독해 완료로 세지 않습니다.
- 신규 후보: 대면 61강좌/1,040회 + 원문 직접 확인 실시간 온라인 2강좌/36회 = 63강좌/1,076회. 누적 후보 3,158강좌/58,934회.
- 불확정 큐 484개는 기존 전체 객체를 그대로 유지합니다. 날짜/시간 부재, 혼합 운영, 공동 교수별 미배정, 개별 연구, 외부 스키장, 미팅 시간 조율, 자체 시각 불일치 등 사유를 구분했습니다. 지원 불가능 판정은 아닙니다.
- 모든 자체 2026-2 학기/캠퍼스/코드/교수/절대 시각/주차 날짜와 원문 교육 필드를 보존했습니다. 실제 원격 운영 또는 평가/발표/보강/현장/미확정 주차를 예약하지 않습니다. 조건부 원격은 자체 대면 기본이 명시된 경우에만 비휴일·비평가 정규 그룹을 좁게 후보 처리했습니다.
- BME42200/ BME32000은 자체 실시간 온라인 선택과 각 교수 계획 일치가 확인된 25회/11회만 liveOnline입니다. 11회는 Sep25/Oct9 휴일 제외 값이며 앞선 수기 12회 기대값을 사용하지 않습니다.
- 기존 047 전체 누적 객체를 보존했습니다. 학교 비고 삭제 0; 제거한 정확 과거 연구 생성 경고는 previous-full-remarks-archive.json에 전체 원문과 함께 보존합니다.
- CHE33405 Nov30는 자체13주 실험/native월요일의 실제 정상 그룹입니다. 일정 삭제 0. 최종 fixture만 예전045 잘못된 제외 기대값을 정정하며 packet045d receipt 근거를 재사용합니다. 원본045 동결 변경 0.
- fixture .dart.txt 하나는 준비만 됐습니다. 실제 SDK/통합 검증 및 제품 반영은 root 담당입니다. 모든 대학 지원 완료·실제 출석·최신 폐강 전체 확인 주장은 하지 않습니다.
- v1/v2/v3 및 실패한 final-v4는 최종 채택본이 아닌 작업 초안입니다. 이 final-v5만 검증/반영 대상으로 사용합니다. 기존 frozen packets는 변경하지 않았습니다.
''')
(P/'freeze-script.py').write_text(Path(__file__).read_text())
files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(P.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'}
(P/'SHA256SUMS.json').write_text(json.dumps({'files':files,'SDKExecutions':0,'productWrites':0,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print(len(files),hashlib.sha256((P/'SHA256SUMS.json').read_bytes()).hexdigest())
