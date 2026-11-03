from pathlib import Path
import json,hashlib
P=Path('work/university-research/three-school-bulk-jeju-hoseo-kongju-v2-20261010')
s=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='__DIR__';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
void main(){test('Three-school entire held bulk classification, own independent clocks and full three-mode Drive preservation',(){
 final proof=read('proof.json') as Map,old=<String,dynamic>{},raw=<String,dynamic>{};final courses=<UniversityCourse>[];
 for(final d in proof['datasets']){
  final previous=read(d['prior'] as String) as Map,current=read(d['candidate'] as String) as Map;
  for(final c in previous['courses']){old[c['sourceId']]=c;}for(final c in current['courses']){raw[c['sourceId']]=c;}
  courses.addAll(UniversityDataset.fromJson(Map<String,dynamic>.from(current)).courses);
 }
 expect(old,hasLength(8269));expect(raw.keys.toSet(),old.keys.toSet());final ps={for(final p in proof['proofs'])p['sourceId']:p};expect(ps,hasLength(114));
 final queue=read('queue.json') as List;expect(queue,hasLength(2748));for(final q in queue){expect(raw[q['sourceId']],old[q['sourceId']],reason:'whole unresolved source object');}
 final archive=read('previous-full-remarks-archive.json') as Map;var originalCount=0,originalDates=0,added=0;
 for(final c in courses){final before=old[c.sourceId] as Map;
  if(!ps.containsKey(c.sourceId)){expect(raw[c.sourceId],before);if((before['schedules'] as List).isNotEmpty){originalCount++;originalDates+=(before['schedules'] as List).length;}continue;}
  final p=ps[c.sourceId] as Map;expect(p['previousWholeObject'],before);expect(archive[c.sourceId],before['remarks']);expect(before['schedules'],isEmpty);expect(c.campus,before['campus']);
  for(final e in before.entries){if(!{'schedules','scheduleStatus','remarks','sourcePartialCoverage','metadata','sourceEducationalMetadata'}.contains(e.key)){expect(raw[c.sourceId][e.key],e.value,reason:'all school native fields ${c.sourceId}/${e.key}');}}
  final school=p['school'] as String;final mdKey=school=='kongju'?'sourceEducationalMetadata':'metadata';
  final priorMetadata=before[mdKey] as Map,currentMetadata=raw[c.sourceId][mdKey] as Map;
  for(final e in priorMetadata.entries){if(!{'heldReason','reservationHoldReasons','holdReasons'}.contains(e.key)){expect(currentMetadata[e.key],e.value,reason:'whole native source metadata ${e.key}');}}
  final source=p['wholeActualSource'];final slots=<Map<String,dynamic>>[];
  if(school=='jeju'){
   expect(before['sourceSchedule'],'화6[수의107] 화7[수의107] 수8[] 수9[]');expect(source['department'],'수의과대학 수의예과');expect(source['grade'],2);expect(source['rawOperatingMethod'],'');
   slots.addAll([{'weekday':2,'startMinute':840,'endMinute':890,'classroom':'수의107'},{'weekday':2,'startMinute':900,'endMinute':950,'classroom':'수의107'},{'weekday':3,'startMinute':960,'endMinute':1010,'classroom':''},{'weekday':3,'startMinute':1020,'endMinute':1070,'classroom':''}]);
  }else if(school=='hoseo'){
   final rows=priorMetadata['originalEducationalRecords'] as List,first=rows.first['values'];expect(first[4],'대면수업');expect(first[8].toString().startsWith('주간'),true);expect(first[10],isNotEmpty);expect(first[11],isNotEmpty);
   const starts=[0,600,660,720,780,840,900,960,1020];const ends=[0,650,710,770,830,890,950,1010,1070];
   final matches=RegExp(r'([월화수목금])([1-8])(?:~([1-8]))?').allMatches(first[9] as String).toList();expect(matches,hasLength(2));
   for(final m in matches){slots.add({'weekday':'월화수목금'.indexOf(m[1]!)+1,'startMinute':starts[int.parse(m[2]!)],'endMinute':ends[int.parse(m[3]??m[2]!)],'classroom':''});}
   expect(currentMetadata['roomWeekdayAllocationConfirmed'],false);
  }else{
   final rows=priorMetadata['originalPublishedRowVariants'] as List;expect(rows.every((r)=>r['roomRaw']==''),true);expect(priorMetadata['holdReasons'],['actualRoomUnpublished']);
   const starts=[480,540,600,660,720,780,840,900,960,1020];const ends=[530,590,650,710,770,830,890,950,1010,1070];
   for(final group in priorMetadata['exactSourcePeriodicBlocks']){final pp=(group['nativePeriods'] as List).cast<int>();expect(pp.every((i)=>i>=0&&i<=9),true);slots.add({'weekday':group['weekday'],'startMinute':starts[pp.first],'endMinute':ends[pp.last],'classroom':''});}
  }
  expect(slots,p['literalFixedSlots']);final expected=<Map<String,dynamic>>[];
  final start=DateTime.parse(p['ownStartLiteral'] as String),end=DateTime.parse(p['ownEndLiteral'] as String);final excluded=(p['ownExcludedDateLiterals'] as List).cast<String>(),exam=(p['ownExamRangeLiteral'] as List).cast<String>();
  for(var d=start;!d.isAfter(end);d=d.add(const Duration(days:1))){final date=d.toIso8601String().substring(0,10);if(excluded.contains(date)||exam.isNotEmpty&&date.compareTo(exam.first)>=0&&date.compareTo(exam.last)<=0)continue;for(final h in slots){if(d.weekday==h['weekday'])expected.add({'date':date,...h});}}
  expect(raw[c.sourceId]['schedules'],expected);expect(c.meetings.length,expected.length);added+=expected.length;expect((raw[c.sourceId]['schedules'] as List).every((m)=>m['deliveryMode']==null),true);
 }
 expect(originalCount,5407);expect(originalDates,132663);expect(added,3213);final scheduled=courses.where((c)=>c.meetings.isNotEmpty).toList();expect(scheduled,hasLength(5521));
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){
  final values=<String,TimetableSyncValue>{};
  for(final c in scheduled){final saved=c.toTimetable(id:c.sourceId,mode:mode);expect(saved.isValid,true);
   for(var i=0;i<saved.meetings.length;i++){final m=saved.meetings[i],native=raw[c.sourceId]['schedules'][i]['deliveryMode'];final expected=native=='inPerson'?LectureMode.inPerson:native=='liveOnline'?LectureMode.liveOnline:mode;expect(saved.modeOn(m,m.teachingDate!),expected);expect(saved.period!.contains(m.teachingDate!),true);}
   final key=timetableCourseSyncKey(saved);expect(values.containsKey(key),false);values[key]=TimetableSyncValue({...saved.toJson(),'id':key},DateTime.utc(2026,10,10),'research');
  }
  final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))as Map<String,dynamic>).materializeClasses();expect(restored,hasLength(5521));for(final c in restored){expect(c.toJson(),values[timetableCourseSyncKey(c)]!.value);}
 }
});}
'''.replace('__DIR__',str(P))
(P/'three_school_combined_fixture_test.dart.txt').write_text(s)
(P/'HANDOFF.md').write_text('''# 제주·호서·공주 전체 미예약 데이터 일괄 처리

SDK·제품·AGENT_MEMORY 수정0. 기존8,269개 전체 객체와5,407강좌/132,663회 일정을 보존합니다. 미예약2,862개를 모두 분류했으며 사람식 원문 전수 독해 완료로 세지 않습니다. 신규114강좌/3,213회, 후보 누적5,521강좌/135,876회. 미확정2,748개는 학교 원문과 실제 제약 사유를 별도 큐로 보존했습니다. 대학 전체 완료/불가능/실제출석 주장은 없습니다.

제주:1210개 분류, 동물관리학Ⅱ 수의예과2학년 실제 화6/7(수의107)·수8/9(빈 방)의4학교정규 교시만52회 추가. 단순 제목으로 임상/집중을 추정하지 않고 실제 일반 운영 원문 및 자체1–9교시를 사용했습니다. 나머지1209개는935시간미공표·133원격·28블렌디드·18미공표범위·실제 광범위 무배정/1S2S/임상기간 등 보존. 수의학과64시간/광범위빈교시를 일반 수의예과 강좌와 동일 처리하지 않았습니다. 기존1885/68304 유지→1886/68356.

호서:981개 분류, 실제 대면·주간·1–8교시 확정 및 오직 두 방의 요일별 대응만 불명인94강좌/2923회 추가. 방 하나를 선택하거나 첫 방을 첫 요일로 배정하지 않고 수업 강의실 빈값+강의실1/2 원문 전체 교육 필드와sourceClassroom 보존. 기존1497+21인1518/26184→1612/29107. 실제 원격688,시각범위589,원문충돌54 등 복수사유 큐887개 유지. 실제 야간9+를 자체 주간 시각으로 연장하지 않았습니다. 기존 캠퍼스 그대로 유지.

공주:671개 분류, 학교 자체0–9 주간 정규 교시 확정 및 오직 실제 방 미게시19강좌/238회 추가. 빈 방 그대로, 수산생명의학개론/임상의학 등 제목과 실제 병원/현장실습 배정을 구분합니다. 기존2004/38175→2023/38413.43기존계약학과승인미확정/91폐강/27원문충돌/193시각범위/235블록·실제개별기간 등 큐652개 보존. 9자리 원본번호를7+2로 분해하지 않았습니다.

각 학교 자체 기간·교시·시험·휴일 규칙만 사용했습니다. 다른 학교 시각/날짜 전파0. 학교 비고 삭제0; 제거한 정확 과거 생성 held suffix와 원래 전체 비고는 이전전체객체/비고 아카이브에 보존하고 metadata의과거생성상태를 따로 기록했습니다. 최종3학교결합fixture 하나는 원문 직접 리터럴시각·8269전체객체·각날짜·3모드Drive복원을 검사하도록 준비만 했습니다. 실제 실행과 통합 검토는root 담당입니다.
''')
(P/'fixture-freeze.py').write_text(Path(__file__).read_text());files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(P.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};(P/'SHA256SUMS.json').write_text(json.dumps({'files':files,'SDKExecutions':0,'productWrites':0,'completionClaim':False},ensure_ascii=False,indent=2)+'\n');print(len(files),hashlib.sha256((P/'SHA256SUMS.json').read_bytes()).hexdigest())
