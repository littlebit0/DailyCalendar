import pathlib,json,hashlib,shutil,datetime
b=pathlib.Path(__file__).parent;o=b/'daegu-sookmyung-ssu-held-native-bulk-v1-20261010'
def load(n):return json.load(open(o/n))
def write(n,v):(o/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
base=load('baseline-daegu-main-2026-2.json');cand=load('daegu-main-2026-2.native-geometry-candidate.json');pos=load('daegu-new-scopes-independent-date-plan.json');ids={p['sourceId'] for p in pos};mutable={'schedules','scheduleStatus','period','remarks','departmentRemarks','datesMeaning','sourceGeometryResolution'}
assert len(ids)==30 and sum(len(c['schedules']) for c in cand['courses'])==55005
for a,z in zip(base['courses'],cand['courses']):
 if a['sourceId'] not in ids:assert a==z
 else:
  assert not a['schedules'];assert {k:v for k,v in a.items() if k not in mutable}=={k:v for k,v in z.items() if k not in mutable};assert a.get('remarks','') in z['remarks']
proof=load('daegu-printed-time-room-geometry-proof.json');caltext=b/'daegu-current-20261008/timetable-2026-2.txt';txt=caltext.read_text();write('daegu-own-calendar-source-excerpt.json',{'existingPDFSHA256':proof['sourcePDFSHA256'],'existingFullTextSHA256':hashlib.sha256(caltext.read_bytes()).hexdigest(),'sourceOfficialURL':'https://rst.daegu.ac.kr/cmmn/fileDown.do?fileSeq=192983','calendarSourceExtract':txt[:txt.find('Ⅰ.') if 'Ⅰ.' in txt else 7000][:12000],'ownStart':'2026-09-01','regularTeachingEndBeforeFinals':'2026-12-07','finalExamStart':'2026-12-08','finalExamEnd':'2026-12-14','winterStart':'2026-12-15','holidayPolicy':'source autonomously assigned makeup dates not individually posted; no fabricated makeup'});
shutil.copyfile(b/'daegu-native-printed-geometry-bulk-20261010.py',o/'daegu-native-printed-geometry-bulk-20261010.py');shutil.copyfile(__file__,o/pathlib.Path(__file__).name)
# The independent fixture uses printed line words, independently re-parses clocks and literal room,
# then builds expected dates. No SDK is executed here.
fixture=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='work/university-research/catalog-c/daegu-sookmyung-ssu-held-native-bulk-v1-20261010';
Map<String,dynamic> read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync()) as Map<String,dynamic>;
void main(){
 final raw=read('daegu-main-2026-2.native-geometry-candidate.json');final prior=read('baseline-daegu-main-2026-2.json');final courses=UniversityDataset.fromJson(raw).courses;
 final proofs=(read('daegu-printed-time-room-geometry-proof.json')['receipts'] as List).where((r)=>r['eligible']==true).toList();final ids=proofs.map((r)=>r['sourceId']).toSet();
 test('All prior whole objects/source fields retained; other schools byte-identical',(){
 expect(proofs,hasLength(30));expect(courses,hasLength(3174));
 const mutable={'schedules','scheduleStatus','period','remarks','departmentRemarks','datesMeaning','sourceGeometryResolution'};
 for(var i=0;i<(raw['courses'] as List).length;i++){final a=prior['courses'][i] as Map;final z=raw['courses'][i] as Map;
 if(!ids.contains(a['sourceId'])){expect(z,a);}else{expect(a['schedules'],isEmpty);expect({for(final e in a.entries)if(!mutable.contains(e.key))e.key:e.value},{for(final e in z.entries)if(!mutable.contains(e.key))e.key:e.value});expect(z['remarks'],contains(a['remarks']));}}
 for(final key in ['sookmyung-first','sookmyung-second','sookmyung-unknown','ssu-main']){expect(File('$dir/$key-2026-2.native-bulk-unchanged.json').readAsBytesSync(),File('$dir/baseline-$key-2026-2.json').readAsBytesSync());}
 });
 test('Original PDF words same-Y; independent raw clock/room/weekday and own-period dates',(){
 final rx=RegExp(r'^([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)$');const excluded={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};var added=0;
 for(final p in proofs){final c=courses.singleWhere((c)=>c.sourceId==p['sourceId']);Set<String>? expected;
 for(final row in p['printedGeometryRows']){final values=<String>{};for(final line in row['directPrintedLines']){expect(((line['clockTop'] as num)-(line['roomTop'] as num)).abs(),lessThanOrEqualTo(.1));final clock=(line['clockWords'] as List).map((w)=>w['text']).join();final room=(line['roomWords'] as List).map((w)=>w['text']).join(' ');expect(clock,line['printedTime']);expect(room,line['printedRoom']);final m=rx.firstMatch(clock)!;final weekday='월화수목금토일'.indexOf(m[1]!)+1;final a=int.parse(m[2]!)*60+int.parse(m[3]!);final z=int.parse(m[4]!)*60+int.parse(m[5]!);
 for(var day=DateTime(2026,9,1);!day.isAfter(DateTime(2026,12,7));day=day.add(const Duration(days:1))){final date=timetableDateKey(day);if(day.weekday==weekday&&!excluded.contains(date))values.add('$date/$weekday/$a/$z/$room');}}
 if(expected==null){expected=values;}else{expect(values,expected);}}
 final actual={for(final m in c.meetings)'${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}'};expect(actual,expected,reason:c.sourceId);expect(actual,hasLength(c.meetings.length));added+=c.meetings.length;}
 expect(added,807);expect(courses.where((c)=>c.meetings.isNotEmpty),hasLength(2801));expect(courses.fold<int>(0,(n,c)=>n+c.meetings.length),55005);
 });
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){test('Whole five assets model + Drive roundtrip, user default ${mode.name}',(){final saved=<TimetableClass>[];for(final key in ['daegu-main','sookmyung-first','sookmyung-second','sookmyung-unknown','ssu-main']){final suffix=key=='daegu-main'?'native-geometry-candidate':'native-bulk-unchanged';final ds=UniversityDataset.fromJson(read('$key-2026-2.$suffix.json'));for(final c in ds.courses.where((c)=>c.meetings.isNotEmpty)){final t=c.toTimetable(id:c.sourceId,mode:mode);expect(t.isValid,true);expect(t.defaultMode,mode);for(final m in t.meetings){expect(m.isValid,true);expect(t.period!.contains(m.teachingDate!),true);expect(t.modeOn(m,m.teachingDate!),mode);}saved.add(t);}}
 expect(saved,hasLength(6126));expect(saved.fold<int>(0,(n,c)=>n+c.meetings.length),135305);final records=<String,TimetableSyncValue>{};for(final t in saved){final key=timetableCourseSyncKey(t);records[key]=TimetableSyncValue({...t.toJson(),'id':key},DateTime.utc(2026,10,10),'source-research');}final doc=TimetableSyncDocument.records(courses:records,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String,dynamic>);expect(restored.materializeClasses(),hasLength(saved.length));for(final t in restored.materializeClasses()){expect(t.toJson(),records[timetableCourseSyncKey(t)]!.value);}});}
}
'''
(o/'daegu_sookmyung_ssu_bulk_actual_test.dart.txt').write_text(fixture)
# Count correction is literal aggregate, not a runtime model test.
total=[cand]+[load(f'{k}-2026-2.native-bulk-unchanged.json') for k in ['sookmyung-first','sookmyung-second','sookmyung-unknown','ssu-main']];counts={'whole':sum(len(d['courses']) for d in total),'scheduled':sum(bool(c['schedules']) for d in total for c in d['courses']),'meetings':sum(len(c['schedules']) for d in total for c in d['courses'])};f=o/'daegu_sookmyung_ssu_bulk_actual_test.dart.txt';s=f.read_text().replace('hasLength(6126)',f"hasLength({counts['scheduled']})").replace(',135305)',f",{counts['meetings']})");f.write_text(s);write('final-source-candidate-counts.json',{'allFiveAssets':counts,'daegu':{'whole':3174,'scheduled':2801,'meetings':55005,'held':373},'sookmyung':{'whole':1485,'scheduled':1281,'meetings':23676,'held':204,'new':0},'ssu':{'whole':2219,'scheduled':2044,'meetings':56624,'held':175,'new':0},'sourceAddedScopes':30,'sourceAddedPlannedMeetings':807,'parserWholeHeldProcessed':782,'SDKExecuted':False,'modelFixturePreparedNotExecuted':True,'humanWholeReadAdded':0,'completionClaim':False})
(o/'HANDOFF.md').write_text('''# 대구·숙명·숭실 현재 원문 보류 일괄 처리 — source-only 2026-10-10

782개(대구403/숙명204/숭실175)의 기존 교육 source 필드를 한 번 일괄 처리했습니다. 새 네트워크0/SDK0/제품0/메모리0/앱 실행0/사람식 전체 원문 판독 추가0입니다. 전체 지원 완료 주장이 아닙니다.

대구는 35개 다중실 표기 중 30개에서 기존 공개 편람 PDF 원문 모든 중복행의 시간·강의실 셀 각 줄이 같은 y좌표(0.1pt 이내)임을 독립 확인했습니다. 단순 두 목록의 순서를 추정한 것이 아닙니다. 원문 수강번호/교수/학점/학과별 분류/비고/모든 aliases·sourceSnapshotSchedules를 보존하고, 직접 줄 대응 강의실로 +30강좌/+807 예정 수업 후보를 만들었습니다. 나머지5개는 인쇄 줄 수·높이 미대응으로 그대로 보류합니다. 확인된 폐강 제외 상태를 보존하며 최근 TIGERS 변경 전수 확인은 주장하지 않습니다. 법학 변경/원문 충돌/원격혼합/집중 표 원문 조건은 계속 보류합니다.

대구 이전2771개/54198개 예약과 해당 객체 전체를 그대로 보존했습니다. 누적3174개 중2801개/55005개 예정 예약, 보류373입니다. 달력은 같은 편람의 9/1개강·12/8~14기말·12/15방학에 따른 정규 주간9/1~12/7 예정 날짜를 파생한 것이며 강좌별 개별 인쇄 일자가 아닙니다. 공휴일 미확정 자율보강을 생성하지 않습니다. 수업 native 실제 HH를 그대로 쓰고 deliveryMode는 사용자 default입니다. 실제 출석/확정 대면 주장0입니다.

숙명204·숭실175는 연구자가 붙인 일반 실제 출석 미확인 문구를 학교 제약으로 사용하지 않았지만, 기존 교육 원문상의 BL배분/녹화/개별운영·불명확 clock·room을 해소하지 못했습니다. 신규0, 4개 전체 파일 byte-identical입니다. 불가능 대학으로 판정하지 않습니다.

`daegu-main-2026-2.native-geometry-candidate.json`이 새 대구 전체 후보입니다. 기존 `*.native-bulk-unchanged.json`은 초기 감사 복사본이며 대구는 최종 후보로 사용하지 않습니다. 다른4파일은 그대로입니다. `daegu-printed-time-room-geometry-proof.json`에는 원본PDF SHA/정확행/셀bbox/단어좌표를, `daegu-new-scopes-independent-date-plan.json`에는 각 예정 날짜를 저장했습니다. 기존 원본PDF는 기존 동결 경로를 그대로 참조하며 재다운로드하지 않았습니다. fixture `.dart.txt`는 전체5asset·기존객체 보존·원문좌표 및 clock 독립 대응·3사용자모드/Drive 왕복 검증용이고 SDK는 실행하지 않았습니다. 최종 통합 검증은 parent가 수행합니다.
''')
files=[]
for p in sorted(o.rglob('*')):
 if p.is_file() and p.name!='immutable-manifest.json':files.append({'path':str(p.relative_to(o)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
write('immutable-manifest.json',{'sourceOnly':True,'completionClaim':False,'SDKExecuted':False,'files':files});print(json.dumps({'path':str(o.resolve()),'manifestSHA256':hashlib.sha256((o/'immutable-manifest.json').read_bytes()).hexdigest(),'counts':counts,'files':len(files)},ensure_ascii=False))
