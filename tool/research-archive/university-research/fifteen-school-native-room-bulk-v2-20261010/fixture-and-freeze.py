# -*- coding: utf-8 -*-
import pathlib,json,hashlib
D=pathlib.Path('work/university-research/fifteen-school-native-room-bulk-v2-20261010')
p=json.loads((D/'proof.json').read_text());s=json.loads((D/'summary.json').read_text())
t=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='work/university-research/fifteen-school-native-room-bulk-v2-20261010';
dynamic read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync());
void main(){test('15 schools native clock, whole original conservation and all user modes Drive',(){
 final proof=read('proof.json')as Map,old=<String,dynamic>{},raw=<String,dynamic>{};final all=<UniversityCourse>[];
 for(final d in proof['datasets']){final a=read(d['prior'])as Map,b=read(d['candidate'])as Map;final ah=Map.of(a)..remove('courses'),bh=Map.of(b)..remove('courses');expect(bh,ah);for(final c in a['courses'])old[c['sourceId']]=c;for(final c in b['courses'])raw[c['sourceId']]=c;all.addAll(UniversityDataset.fromJson(Map<String,dynamic>.from(b)).courses);}
 expect(old,hasLength(33294));expect(raw.keys.toSet(),old.keys.toSet());final selected={for(final p in proof['newCourses'])p['sourceId']:p};expect(selected,hasLength(166));expect(read('queue.json'),hasLength(2550));final archive=read('previous-full-remarks-archive.json')as Map;
 var base=0,baseObjects=0,added=0;
 for(final c in all){final before=old[c.sourceId]as Map,current=raw[c.sourceId]as Map;if(!selected.containsKey(c.sourceId)){expect(current,before);if((before['schedules']as List).isNotEmpty){base++;baseObjects+=(before['schedules']as List).length;}continue;}
 final p=selected[c.sourceId]as Map,school=p['school'];expect(p['originalWholeObject'],before);expect(before['schedules'],isEmpty);expect(archive[c.sourceId],{'remarks':before['remarks'],'departmentRemarks':before['departmentRemarks'],'metadata':before['metadata']});
 for(final e in before.entries){if(!{'schedules','scheduleStatus','period','metadata','remarks'}.contains(e.key))expect(current[e.key],e.value,reason:'Original educational field ${c.sourceId}/${e.key}');}
 final slots=<Map<String,dynamic>>[];
 if(school=='scnu'){
  const night={11:[1080,1125],12:[1130,1175],13:[1180,1225],14:[1230,1275],15:[1280,1325]};
  for(final b in before['nativePeriodBlocks']){final n=b['nativePeriod']as int;expect(n,inInclusiveRange(1,15));final a=n<=10?(n+8)*60:night[n]![0],z=n<=10?(n+8)*60+50:night[n]![1];expect(b['startMinute'],a);expect(b['endMinute'],z);slots.add({'weekday':b['weekday'],'startMinute':a,'endMinute':z,'classroom':''});}
  final reason=p['wholeSourceEvidence']['sourceReason'];expect(['room notation needs meeting-specific interpretation','published classroom absent/unconfirmed; room notation needs meeting-specific interpretation'],contains(reason));expect(current['remarks'],(before['remarks']as String).replaceAll(' 일정 미생성: $reason',''));if(before.containsKey('metadata'))expect(current['metadata'],before['metadata']);
 }else if(school=='hanbat'){
  final md=before['metadata']as Map,row=md['originalEducationalFields'];expect(row['operatingStatus'],'개설');expect(['개별 강의실 미확인','원본 교시와 강의실 대응 미확인'],contains(md['heldReason']));final expectedMetadata=Map.of(md)..['previousGeneratedHeldReason']=md['heldReason']..['heldReason']='';expect(current['metadata'],expectedMetadata);expect(current['remarks'],(before['remarks']as String).replaceAll(' 예약 보류: ${md['heldReason']}',''));
  const night={10:[1120,1170],11:[1175,1225],12:[1230,1280],13:[1290,1340]},sat={6:[840,890],7:[895,945],8:[950,1000],9:[1005,1055],10:[1060,1110],11:[1115,1165],12:[1170,1220],13:[1225,1275]};
  final source=(row['rawSchedule']as String).replaceAll(RegExp(r'\s'),'');final matches=RegExp(r'([월화수목금토일])([^월화수목금토일]+)').allMatches(source).toList();expect(matches.map((m)=>m[0]).join(),source);
  for(final m in matches){final day='월화수목금토일'.indexOf(m[1]!)+1;expect(day,inInclusiveRange(1,6));for(final token in m[2]!.replaceAll(RegExp(r'^,|,$'),'').split(',')){expect(RegExp(r'^\d+$').hasMatch(token),true);final n=int.parse(token);expect(n,inInclusiveRange(1,13));final a=day==6&&n>=6?sat[n]![0]:day!=6&&n>=10?night[n]![0]:(n+8)*60,z=day==6&&n>=6?sat[n]![1]:day!=6&&n>=10?night[n]![1]:(n+8)*60+50;slots.add({'weekday':day,'startMinute':a,'endMinute':z,'classroom':''});}}
 }else if(school=='jnu'){
  expect(c.sourceId,'jnu-yeosu-2026-2-HME8004-1');expect(before['courseCode'],'HME8004');expect(before['section'],'1');expect(before['sourceSchedule'],'월8월9수8수9');expect(current['remarks'],before['remarks']);if(before.containsKey('metadata'))expect(current['metadata'],before['metadata']);
  slots.addAll([{'weekday':1,'startMinute':960,'endMinute':1070,'classroom':''},{'weekday':3,'startMinute':960,'endMinute':1070,'classroom':''}]);expect(p['wholeSourceEvidence']['sameUniversityCurrentTerm']['start'],'2026-09-01');expect(p['wholeSourceEvidence']['sameUniversityCurrentTerm']['end'],'2026-12-21');
 }else{fail('Unsupported school cannot acquire invented HH');}
 expect(slots,p['literalSlots']);final expected=<Map<String,dynamic>>[];final end=DateTime(2026,12,school=='scnu'?7:school=='hanbat'?14:21);expect(current['period'],{'startDate':'2026-09-01','endDate':end.toIso8601String().substring(0,10)});
 if(school=='jnu'){expected.addAll(slots);expect(p['dateRule']['rawWeeklySource'],true);}else{final excluded={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};if(school=='scnu')excluded.addAll(['2026-10-19','2026-10-20','2026-10-21','2026-10-22','2026-10-23']);for(var d=DateTime(2026,9,1);!d.isAfter(end);d=d.add(const Duration(days:1))){final date=d.toIso8601String().substring(0,10);if(excluded.contains(date))continue;for(final b in slots)if(b['weekday']==d.weekday)expected.add({...b,'date':date});}}
 expect(current['schedules'],expected);expect(current['bulkCurrentReservationReview']['actualAttendanceConfirmed'],false);expect(c.campus,before['campus']);added+=expected.length;
 }
 expect(base,30578);expect(baseObjects,192473);expect(added,6356);final scheduled=all.where((c)=>c.meetings.isNotEmpty).toList();expect(scheduled,hasLength(30744));
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){final values=<String,TimetableSyncValue>{};for(final c in scheduled){final saved=c.toTimetable(id:c.sourceId,mode:mode);expect(saved.isValid,true);for(var i=0;i<saved.meetings.length;i++){final m=saved.meetings[i];final native=raw[c.sourceId]['schedules'][i]['deliveryMode'];final expected=native=='inPerson'?LectureMode.inPerson:native=='liveOnline'?LectureMode.liveOnline:mode;expect(saved.modeOn(m,m.teachingDate??DateTime(2026,9,1)),expected);if(m.teachingDate!=null&&saved.period!=null)expect(saved.period!.contains(m.teachingDate!),true);}final key=timetableCourseSyncKey(saved);expect(values.containsKey(key),false);values[key]=TimetableSyncValue({...saved.toJson(),'id':key},DateTime.utc(2026,10,10),'research');}final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))as Map<String,dynamic>).materializeClasses();expect(restored,hasLength(30744));for(final c in restored)expect(c.toJson(),values[timetableCourseSyncKey(c)]!.value);}
 });}
'''
# matcher name matches flutter_test API


(D/'fifteen_school_combined_fixture_test.dart.txt').write_text(t)
(D/'HANDOFF.md').write_text("# 15개 대학 기존 native bulk 처리\n\n전체33294 객체/미예약2716 처리. 신규166 강좌/6356 시간 객체. 기존30578 예약/192473 시간 객체 보존, 최종30744/198829. 큐2550. SDK/제품/AGENT_MEMORY/네트워크0. 전체완료·실제출석·불가능 주장0.\n\n"+''.join(f"- {k}: 전체{v['whole']}, 처리{v['processedHeld']}, 신규{v['newScheduled']}/{v['newMeetings']}, 큐{v['queue']}.\n"for k,v in s.items())+"\n순천155: 자체 전체 nativePeriodBlocks/학교 교시표 일치, 장소 대응만 미확정. 전체 원문 장소 보존/예약 장소 빈값. 9월1일–12월7일, 10월19–23 중간고사와 공휴일 제외. 낮10/밤11 다른 끝시각 보존, campusunknown 추정0.\n한밭10: 현재 개설, 자체 평일/토요일1–13 전체 exact시각 확인. 0/14이상/소수/일요일 추정0. 원문전체 교실 보존/예약 장소 빈값. 9월1일–12월14일과 공휴일 제외.\n전남 여수HME8004-1: 원문 월8월9수8수9, 월/수16:00–17:50 두 주간 슬롯. 기존 native구조처럼 날짜 없음 유지/자체기간9월1일–12월21일. 신규6356은 날짜객체6354+주간객체2이다. 시험/보강 추정0, 모든 학교 장소 원문 보존.\n나머지 미공표 시각/remote/개별/집중 실제 제약은 큐에 원문과 함께 유지, 같은 자료 반복조사하지 않는다.\n모든 미선정whole/학교 header 불변. exactgeneratedroomwarning만 제거, 이전 전체 remarks/metadata 외부 archive. 최종fixture하나 prepared/SDK0, 기존 날짜 없는 슬롯 및 nullableperiod 보존, 3모드 Drive roundtrip 준비. frozen 이후 생성기 재실행 금지.\n")
(D/'fixture-and-freeze.py').write_bytes(pathlib.Path(__file__).read_bytes())
files={f.name:{'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size}for f in sorted(D.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'}
(D/'SHA256SUMS.json').write_text(json.dumps({'files':files},ensure_ascii=False,indent=2)+'\n')
print(len(files),hashlib.sha256((D/'SHA256SUMS.json').read_bytes()).hexdigest())
