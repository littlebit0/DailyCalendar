import json,pathlib,hashlib,shutil
b=pathlib.Path(__file__).parent;o=b/'fifteen-school-held-education-bulk-v1-20261010';repo=b.parents[2]
def load(n):return json.load(open(o/n))
def write(n,d):(o/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
progress=load('processing-progress.json');pos=load('new-ordinary-native-scopes-independent-plan.json');ids={p['sourceId'] for p in pos};allowed={'schedules','period','scheduleStatus','remarks','departmentRemarks','sourceScheduleResolution'};preserved=0
for key in progress['allAssets']:
 a=load('baseline-'+key+'.json');z=load(key+'.source-candidate.json');assert {k:v for k,v in a.items() if k!='courses'}=={k:v for k,v in z.items() if k!='courses'}
 for x,y in zip(a['courses'],z['courses']):
  if x['sourceId'] not in ids:assert x==y;preserved+=1
  else:assert not x['schedules'];assert {k:v for k,v in x.items() if k not in allowed}=={k:v for k,v in y.items() if k not in allowed}
for src in [repo/'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009/notice-102907-file0.jpg',repo/'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009/notice-103190-image0.png',repo/'work/university-research/catalog-k/bnue-2026-2-current.xlsx']:shutil.copyfile(src,o/src.name)
notice=repo/'work/university-research/catalog-k/bnue-current-schedule-notice.html';text=notice.read_text();assert '9:00~9:50' in text and '17:00~17:50' in text;write('bnue-current-clock-native-source-receipt.json',{'sourcePath':str(notice.resolve()),'sourceSHA256':hashlib.sha256(notice.read_bytes()).hexdigest(),'sourcePrintedClockLiterals':['9:00~9:50','17:00~17:50'],'nativeClockPolicy':'own current notice 1–9 periods, start9:00 thenhourly 50min; current XLSX exact first/last period headers','freshNetwork':False})
write('whole-preservation-source-receipt.json',{'allOtherWholeObjectsExactlyUnchanged':preserved,'changedScopes':20,'newPlannedMeetings':372,'sourceFieldsExactOutsideDocumentedProjection':True,'oldRemarksPreservedAsHistoricalRecord':True,'SDKExecuted':False,'actualModelFixtureExecuted':False,'completionClaim':False})
fixture=r'''import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
const dir='work/university-research/catalog-c/fifteen-school-held-education-bulk-v1-20261010';
Map<String,dynamic> read(String n)=>jsonDecode(File('$dir/$n').readAsStringSync()) as Map<String,dynamic>;
void main(){
 final progress=read('processing-progress.json');final keys=(progress['allAssets'] as List).cast<String>();final plans=jsonDecode(File('$dir/new-ordinary-native-scopes-independent-plan.json').readAsStringSync()) as List;final ids=plans.map((p)=>p['sourceId']).toSet();
 test('All 15 school source fields and prior schedules retained, only20 definite native scopes added',(){
 expect(plans,hasLength(20));expect(progress['heldProcessed'],1249);const allowed={'schedules','period','scheduleStatus','remarks','departmentRemarks','sourceScheduleResolution'};
 var additions=0;
 for(final key in keys){final prior=read('baseline-$key.json');final candidate=read('$key.source-candidate.json');expect({for(final e in prior.entries)if(e.key!='courses')e.key:e.value},{for(final e in candidate.entries)if(e.key!='courses')e.key:e.value});expect(candidate['courses'].length,prior['courses'].length);
 for(var i=0;i<prior['courses'].length;i++){final a=prior['courses'][i] as Map;final z=candidate['courses'][i] as Map;
 if(!ids.contains(a['sourceId'])){expect(z,a);}else{expect(a['schedules'],isEmpty);expect({for(final e in a.entries)if(!allowed.contains(e.key))e.key:e.value},{for(final e in z.entries)if(!allowed.contains(e.key))e.key:e.value});additions+=(z['schedules'] as List).length;}}}
 expect(additions,372);
 });
 test('Independent native periods, room, actual weekday and owncalendar exclusions; no fabricated professor',(){
 const holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};var added=0;
 for(final plan in plans){final raw=read('${plan['asset']}.source-candidate.json');final record=(raw['courses'] as List).singleWhere((c)=>c['sourceId']==plan['sourceId']);final c=UniversityDataset.fromJson(raw).courses.singleWhere((c)=>c.sourceId==plan['sourceId']);final isNsu=(plan['asset'] as String).startsWith('nsu-');final source=isNsu?record['publicImageEducation']:record['sourceEducation']['nativePublicBlock'];final expected=<String>{};
 if(isNsu){expect(record['professor'],'');expect(record['sourceClassroom'],'');expect(record['closureExactTitleSectionTeacherMatches'],isEmpty);for(var day=DateTime(2026,8,31);!day.isAfter(DateTime(2026,12,19));day=day.add(const Duration(days:1))){final date=timetableDateKey(day);if(day.weekday!=source['weekday']||holidays.contains(date))continue;for(final period in source['periods']){final start=(8+(period as int))*60;expected.add('$date/${source['weekday']}/$start/${start+50}/');}}}
 else{expect(source['professorUnassignedNativeLabel'],true);expect(record['professor'],source['professor']);expect(['신규','신규교수','신규강사'],contains(record['professor']));final a=(8+(source['firstPeriod'] as int))*60;final z=(8+(source['lastPeriod'] as int))*60+50;expect(source['startMinute'],a);expect(source['endMinute'],z);
 for(var day=DateTime(2026,9,1);!day.isAfter(DateTime(2026,12,7));day=day.add(const Duration(days:1))){final date=timetableDateKey(day);if(day.weekday!=source['weekday']||holidays.contains(date)||date=='2026-09-02')continue;final grade=source['grade'];if(grade==2&&!day.isBefore(DateTime(2026,10,12))&&!day.isAfter(DateTime(2026,10,23)))continue;if(grade==3&&!day.isBefore(DateTime(2026,11,2))&&!day.isAfter(DateTime(2026,11,13)))continue;expected.add('$date/${source['weekday']}/$a/$z/${source['classroom']}');}}
 final actual={for(final m in c.meetings)'${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}'};expect(actual,expected,reason:c.sourceId);expect(actual,hasLength(c.meetings.length));added+=c.meetings.length;}
 expect(added,372);
 });
 for(final mode in [LectureMode.inPerson,LectureMode.liveOnline,LectureMode.video]){test('Only changed two schools whole model and Drive user-default roundtrip ${mode.name}',(){final values=<String,TimetableSyncValue>{};var appointments=0;for(final key in ['nsu-unknown-2026-2','bnue-unknown-2026-2']){final ds=UniversityDataset.fromJson(read('$key.source-candidate.json'));for(final c in ds.courses.where((c)=>c.meetings.isNotEmpty)){final t=c.toTimetable(id:c.sourceId,mode:mode);expect(t.isValid,true);expect(t.defaultMode,mode);for(final m in t.meetings){expect(m.isValid,true);expect(t.period!.contains(m.teachingDate!),true);expect(t.modeOn(m,m.teachingDate!),mode);}appointments+=t.meetings.length;final id=timetableCourseSyncKey(t);values[id]=TimetableSyncValue({...t.toJson(),'id':id},DateTime.utc(2026,10,10),'source-research');}}
 expect(values,hasLength(392));expect(appointments,7510);final doc=TimetableSyncDocument.records(courses:values,schemaVersion:2);final restored=TimetableSyncDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String,dynamic>);expect(restored.materializeClasses(),hasLength(values.length));for(final t in restored.materializeClasses()){expect(t.toJson(),values[timetableCourseSyncKey(t)]!.value);}});}
}
'''
# Native aggregate correction, not execution of the actual-model fixture.
selected=[load(k+'.source-candidate.json') for k in ['nsu-unknown-2026-2','bnue-unknown-2026-2']];num=sum(bool(c['schedules']) for d in selected for c in d['courses']);meet=sum(len(c['schedules']) for d in selected for c in d['courses']);fixture=fixture.replace('hasLength(392)',f'hasLength({num})').replace(',7510)',f',{meet})');(o/'fifteen_school_source_bulk_actual_test.dart.txt').write_text(fixture)
shutil.copyfile(__file__,o/pathlib.Path(__file__).name)
(o/'HANDOFF.md').write_text(f'''# 15대학 기존 보류 원문 일괄 처리 — 2026-10-10

목포해양·계명·교원·경기·국민·남서울·광주과기원·항공·경국·부산교대·공학·건국·전북·광주교대·청주교대의 현재 보류1249개 전체를 저장된 교육 source 필드로 일괄 처리했습니다. 일반 실제 출석 미확인 경고는 학교 운영 제약으로 사용하지 않았습니다. 새 네트워크0/SDK0/제품0/메모리0/앱 실행0, 사람식 전체문서 판독 추가0입니다. 금오·울산 파일은 범위 밖이며 수정0입니다.

남서울 교수·방 미인쇄11문서항목에서 원문 명시 요일·교시 및 자체 직접HH가 확정되어 정규 예정 수업을 생성했습니다. 교수/방/코드/분반 미공개 값은 그대로이며 다른 강좌 교수·방을 차용하지 않았습니다. 자체8/31개강·16주12/19까지·12/21방학의 기존 근거를 쓰고 법정휴일만 제외, 미게시 시험/보강 생성0. 외부실습4·실제폐강BIM02·공동교수/졸업논문 배정5는 기존 보류 유지합니다.

부산교대 교수란 신규/신규교수/신규강사9문서블록은 원문 단일 제목/요일/자체50분 교시/실이 명시되었으므로 일반 계획을 생성했습니다. 해당 단어를 확정 교수 이름으로 바꾸지 않고 native label 그대로 보존합니다. 자체9/1~12/7 정규 계획,9/2보수 제외·공휴일·2학년10/12~23실습·3학년11/2~13실습·12/8~14기말 제외. 실제 개별교수배정/출석/최신 폐강 확정 주장0입니다.

두학교 합계 +20개/+372개 예정 예약, 기존 전체 객체·raw교육문/교수/교실/분반·기존예약 정확 보존. 이외13대학 전체는 변경0입니다. `processing-progress.json`에 학교별 누적수·보류수/원문 제약 분포를 기록했습니다. 각 `*.source-candidate.json`은 해당 전체asset 후보이며 baseline과 대응합니다. 모든1249개 큐의 source교육/원문HH/실제 제약/연구경고 미사용을 기록했습니다. 강좌별 HH 미공개, recorded/contact배분, 현재 원문 폐강, 서로 다른clock, 실제 A–F/분반·lab 의미 미확정은 그대로 보류했습니다. GISTlab 분반 전파0, CJE숫자교시 clock 추정0, GNUE A–F 해석 추정0입니다.

전체 추가20개 날짜는 source별 직접 교시/요일·자체학기에서 파생한 예정 날짜이며 원문이 개별날짜 전부 인쇄했다고 주장하지 않습니다. deliveryMode는 null 사용자default 유지. `.dart.txt` 단일fixture는 전체source보존/독립 교시·학기/3defaultmode·Drive 검증용 준비 상태이며 SDK 미실행입니다. 현재 두학교 전체 {num}개/{meet}개 예약, 통합 검증은 parent 최종 단계에 남아 있습니다. 완료/불가능대학 주장0.
''')
files=[{'path':str(p.relative_to(o)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(o.rglob('*')) if p.is_file() and p.name!='immutable-manifest.json'];write('immutable-manifest.json',{'sourceOnly':True,'completionClaim':False,'SDKExecuted':False,'files':files});print(json.dumps({'path':str(o.resolve()),'manifestSHA256':hashlib.sha256((o/'immutable-manifest.json').read_bytes()).hexdigest(),'files':len(files),'twoSchoolWhole':num,'twoSchoolMeetings':meet},ensure_ascii=False))
