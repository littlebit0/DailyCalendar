from pathlib import Path
import json,hashlib
P=Path('work/university-research/catalog-r/koreatech/bulk-current-native-clock-v5-20261010')
s=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='__DIR__';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
// Independent literal clock from the school's own current mechatronics grid; no general department transfer.
const ownSlots={
'MTC743':[[3,1080,1140]],'MTC753':[[3,900,930],[3,1140,1170]],
'MTC905':[[5,1080,1200]],'MTC906':[[3,930,960],[5,1200,1290]],'MTD431':[[3,540,720]]};
void main(){test('KoreaTech entire737held census and five blank-room own-clock groups preserve all791 and three-mode Drive',(){
 final old=read('prior-whole.json') as Map,raw=read('candidate.json') as Map,proof=read('proof.json') as Map;
 final before={for(final c in old['courses'])c['sourceId']:c};final after={for(final c in raw['courses'])c['sourceId']:c};
 final ps={for(final p in proof['proofs'])p['sourceId']:p};final archive=read('previous-full-remarks-archive.json') as Map;
 final queue=read('queue.json') as List;expect(before,hasLength(791));expect(after.keys.toSet(),before.keys.toSet());expect(queue,hasLength(732));expect(ps,hasLength(5));
 for(final q in queue){expect(after[q['sourceId']],before[q['sourceId']],reason:'whole unresolved object unchanged');}
 final dataset=UniversityDataset.fromJson(Map<String,dynamic>.from(raw));var baseCount=0,baseDates=0,added=0;
 for(final c in dataset.courses){final previous=before[c.sourceId] as Map;
  if(!ps.containsKey(c.sourceId)){expect(after[c.sourceId],previous);if((previous['schedules'] as List).isNotEmpty){baseCount++;baseDates+=(previous['schedules'] as List).length;}continue;}
  final p=ps[c.sourceId] as Map;expect(p['previousWholeObject'],previous);expect(archive[c.sourceId],previous['remarks']);expect(c.campus,'unknown');expect(previous['schedules'],isEmpty);
  for(final e in previous.entries){if(!{'schedules','scheduleStatus','remarks','metadata','sourcePartialCoverage'}.contains(e.key)){expect(after[c.sourceId][e.key],e.value,reason:'native education preserved ${e.key}');}}
  final pm=previous['metadata'] as Map,nm=after[c.sourceId]['metadata'] as Map;
  for(final e in pm.entries){if(e.key!='heldReason'){expect(nm[e.key],e.value);}}
  expect(nm['previousGeneratedHeldReason'],pm['heldReason']);expect(nm['heldReason'],'');expect(nm['actualAttendanceConfirmed'],false);expect(nm['actualPhysicalDatesConfirmed'],false);
  final expected=<Map<String,dynamic>>[];final code=previous['courseCode'] as String;
  for(var day=DateTime(2026,8,31);!day.isAfter(DateTime(2026,12,6));day=day.add(const Duration(days:1))){
   final date=day.toIso8601String().substring(0,10);if(['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02'].contains(date))continue;
   for(final h in ownSlots[code]!){if(h[0]==day.weekday){expected.add({'date':date,'weekday':h[0],'startMinute':h[1],'endMinute':h[2],'classroom':''});}}
  }
  expect(after[c.sourceId]['schedules'],expected);expect(c.meetings.every((m)=>m.classroom.isEmpty),true);expect((after[c.sourceId]['schedules'] as List).every((m)=>m['deliveryMode']==null),true);
  added+=expected.length;
 }
 expect(baseCount,54);expect(baseDates,1198);expect(added,94);
 final scheduled=dataset.courses.where((c)=>c.meetings.isNotEmpty).toList();expect(scheduled,hasLength(59));expect(scheduled.fold<int>(0,(n,c)=>n+c.meetings.length),1292);
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){
  final classes=scheduled.map((c)=>c.toTimetable(id:c.sourceId,mode:mode)).toList();
  final doc=TimetableSyncDocument.legacy(courses:classes,termNames:{},activeYear:2026,activeSemester:'2');
  final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))as Map<String,dynamic>).materializeClasses();expect(restored,hasLength(59));
  final byId={for(final c in classes)c.sourceId:c};
  for(final c in restored){final original=byId[c.sourceId]!;final expected=Map<String,Object?>.from(original.toJson());expected['id']='source/${jsonEncode([2026,'2',original.sourceId])}';expect(c.toJson(),expected);expect(c.defaultMode,mode);expect(c.isValid,true);for(final m in c.meetings){expect(c.modeOn(m,DateTime.parse(m.date!)),mode);}}
 }
});}
'''.replace('__DIR__',str(P))
(P/'koreatech_bulk_final_fixture_test.dart.txt').write_text(s)
(P/'HANDOFF.md').write_text('''# 한국기술교육대 737개 미예약 전체 source-only 재분류

현재 791개 전체 원본/54강좌·1,198회 예약을 보존한 채 미예약737개를 전부 실제 원문 조건으로 분류했습니다. 실제 등교 미확인 문구 자체를 보류 사유로 사용하지 않습니다. 신규5강좌·94회, 최신 후보59강좌·1,292회. 미확정732개는 학교 교육 전체 필드와 근거를 보존했습니다.

신규 MTC743-01/MTC753-01/MTC905-01/MTC906-01/MTD431-01은 동일 메카트로닉스 현재 원본코드·분반·교시가 양 원문에서 정확히 대응합니다. 원문 강의실 미공개를 빈값으로 두며 MTD431 실습시간 없는 실습실 C208을 강의실로 빌리지 않습니다. 공학/졸업설계 제목 자체를 개별 운영 미확정의 증거로 삼지 않습니다. 원본 김택근과 학부장 교수 역할 표기 모두 보존하며 교수를 임의 교정하지 않습니다. 실제 고정 공개 개설 예약을 처리하는 것이고 실제 출석/개별지도 완료를 주장하지 않습니다.

다수 나머지729개는 현재 확보된 절대 시각이 적용되는 해당 학부 원문 행의 연결 근거가 없습니다(다른 사유와 중복). 학교 전체 native06A/06B표기가 있다는 이유로 메카트로닉스 또는 산업경영 시각 표를 다른 학부로 전파하지 않습니다. 8개 실제 폐강/폐설,2개 같은코드분반 시간·제목 상충,1개 플립 운영 미확정 등은 그대로 유지합니다. 대학 지원 불가능 판정이 아닙니다.

학교 자체8/31 개강,12/7–11교육심화향상 및12/14–18기말 경계와 기존 정책을 유지해 정규예약은12/6까지입니다.12/20은 방학 전날 산출 경계이지 실제 마지막 강의일이 아닙니다. 기존11/2개교기념일 보수 제외를 그대로 유지하되 학교가 명시 휴강했다고 주장하지 않습니다. 캠퍼스는unknown으로 유지합니다.

기존 전체 수업 객체·원본 학교 비고 및 모든 이수/제한 필드는 보존합니다. 새5개에 실제 과거 생성 held 상태만 별도 previousGeneratedHeldReason과 전체 이전 비고 아카이브로 보존·정정했습니다. 단일 최종 fixture는 자체 리터럴 HH와 날짜·모든791객체·59수업3모드Drive복원을 검증하도록 준비만 했습니다. SDK·제품·AGENT_MEMORY 수정0, 실제 검증 완료 아님.
''')
(P/'fixture-freeze.py').write_text(Path(__file__).read_text());fs={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(P.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};(P/'SHA256SUMS.json').write_text(json.dumps({'files':fs,'SDKExecutions':0,'productWrites':0,'completionClaim':False},ensure_ascii=False,indent=2)+'\n');print(len(fs),hashlib.sha256((P/'SHA256SUMS.json').read_bytes()).hexdigest())
