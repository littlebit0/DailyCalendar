import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/cnu-native-topic-versus-operation-v8-20261009';
const prior =
    'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
void main() {
  final audit = read('$folder/candidate-audit.json');
  final raw = read('$folder/${audit['candidateFile']}');
  final baseline = read(audit['baselinePath'] as String);
  final unknown = UniversityDataset.fromJson(raw);
  final daedeokRaw = read(audit['unchangedDaedeokPath'] as String);
  final daedeok = UniversityDataset.fromJson(daedeokRaw);
  final all = [...unknown.courses, ...daedeok.courses];
  final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
  final native =
      jsonDecode(
            fixtureFile(
              '$prior/current-public-native-educational-catalog.json',
            ).readAsStringSync(),
          )
          as List;
  test('whole3888 independent native union and prior1735 unchanged', () {
    expect(all, hasLength(3888));
    expect(all.where((c) => c.hasSchedulableMeetings), hasLength(1740));
    expect(all.expand((c) => c.meetings), hasLength(43121));
    expect(proofs, hasLength(5));
    expect(native, hasLength(3888));
    expect(native.map((r) => r['COURSE_NO']).toSet(), hasLength(3888));
    expect(all.map((c) => c.sourceId).toSet(), hasLength(3888));
    final old = baseline['courses'] as List;
    final current = raw['courses'] as List;
    expect(
      [
        ...current,
        ...(daedeokRaw['courses'] as List),
      ].map((c) => c['sourceEducation']['courseId']).toSet(),
      native.map((r) => r['COURSE_NO']).toSet(),
    );
    expect(
      sha256
          .convert(
            fixtureFile(audit['baselinePath'] as String).readAsBytesSync(),
          )
          .toString(),
      audit['baselineSHA256'],
    );
    expect(
      sha256
          .convert(
            fixtureFile('$folder/${audit['candidateFile']}').readAsBytesSync(),
          )
          .toString(),
      audit['candidateSHA256'],
    );
    expect(daedeokRaw, read('$prior/baseline-cnu-daedeok-v1.json'));
    expect(daedeok.courses.single.meetings, hasLength(15));
    for (var i = 0; i < current.length; i++) {
      final c = current[i];
      expect(c['sourceId'], old[i]['sourceId']);
      if (!proofs.containsKey(c['sourceId'])) {
        expect(c, old[i]);
      } else {
        final restored = Map<String, dynamic>.from(c as Map);
        restored.remove('reservationEvidence');
        restored.remove('previousResearchDepartmentRemarks');
        restored.remove('currentPublicPlanEducation');
        expect(
          c['previousResearchDepartmentRemarks'],
          old[i]['departmentRemarks'],
        );
        for (final key in [
          'schedules',
          'scheduleStatus',
          'period',
          'departmentRemarks',
        ]) {
          if ((old[i] as Map).containsKey(key)) {
            restored[key] = old[i][key];
          } else {
            restored.remove(key);
          }
        }
        expect(restored, old[i]);
      }
    }
  });
  test('all5 exact nativeHHroom currentUG source and complete date plans', () {
    final term = read(
      'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json',
    );
    expect(term['normalTeachingPeriod'], {
      'start': '2026-09-01',
      'end': '2026-12-18',
    });
    final pattern = RegExp(
      r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})\(((?:[^()]|\([^()]*\))*)\)',
    );
    var addedCount = 0;
    for (final c in all.where((c) => proofs.containsKey(c.sourceId))) {
      final p = proofs[c.sourceId];
      expect(c.campus, 'unknown');
      final source = read(p['sourcePlanFile']);
      expect(source['courseId'], p['courseId']);
      expect(source['planPresent'], true);
      expect(
        sha256
            .convert(fixtureFile(p['sourcePlanFile']).readAsBytesSync())
            .toString(),
        p['sourcePlanSHA256'],
      );
      expect(source, p['wholeCurrentOriginalEducationalPlan']);
      for (final h in source['header']) {
        expect(h['OPEN_SHTM_CD_NM'], '2학기');
        expect(h['LSN_OPER_UNTACT_YN'], '0');
      }
      final n = native.singleWhere((n) => n['COURSE_NO'] == p['courseId']);
      expect(n['OPEN_YR'], '2026');
      expect(n['OPEN_SHTM_CD'], 'USR01.20');
      expect(n['OBJ_CORS_CD_NM'], '학사과정');
      expect(n['CLOSE_YN'], '0');
      expect(c.code, n['OPEN_SBJT_NO']);
      expect(c.section, n['OPEN_DCLSS']);
      final slots = pattern.allMatches(n['TMTBL_INFO'] as String).toList();
      expect(slots, isNotEmpty);
      final expected = <String>{};
      for (
        var d = DateTime(2026, 9, 1);
        !d.isAfter(DateTime(2026, 12, 18));
        d = d.add(const Duration(days: 1))
      ) {
        final date = d.toIso8601String().substring(0, 10);
        if ((audit['closedDates'] as List).contains(date)) {
          continue;
        }
        for (final s in slots) {
          final weekday = '월화수목금토일'.indexOf(s[1]!) + 1;
          if (d.weekday == weekday) {
            expected.add(
              '$date|$weekday|${int.parse(s[2]!) * 60 + int.parse(s[3]!)}|${int.parse(s[4]!) * 60 + int.parse(s[5]!)}|${s[6]}',
            );
          }
        }
      }
      final actual = c.meetings
          .map(
            (m) =>
                '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
          )
          .toList();
      expect(actual.toSet(), expected);
      expect(actual, hasLength(expected.length));
      for (var i = 0; i < c.meetings.length; i++) {
        final m = c.meetings[i];
        expect(DateTime.parse(m.date!).weekday, m.weekday);
        for (final other in c.meetings.skip(i + 1)) {
          if (other.date == m.date) {
            expect(
              m.originalEndMinute <= other.originalStartMinute ||
                  other.originalEndMinute <= m.originalStartMinute,
              true,
            );
          }
        }
      }
      addedCount += c.meetings.length;
    }
    expect(addedCount, 102);
  });
  test('full1740 records allthree actual modes and completeDrive equality', () {
    final exports = <Map<String, dynamic>>[];
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      for (final c in all.where((c) => c.hasSchedulableMeetings)) {
        final t = c.toTimetable(id: c.sourceId, mode: mode);
        expect(t.isValid, true, reason: c.sourceId);
        expect(t.defaultMode, mode);
        final key = timetableCourseSyncKey(t);
        expect(values.containsKey(key), false, reason: c.sourceId);
        values[key] = TimetableSyncValue(
          {...t.toJson(), 'id': key},
          DateTime.utc(2026, 10, 9),
          'research',
        );
      }
      expect(values, hasLength(1740));
      final document = TimetableSyncDocument.records(courses: values);
      final encoded = jsonEncode(document.toJson());
      final decoded = TimetableSyncDocument.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), document.toJson());
      for (final e in values.entries) {
        expect(decoded.courses[e.key]!.value, e.value.value);
      }
      final path = '/private/tmp/cnu-v8-full-drive-${mode.name}.json';
      final output = fixtureOutputFile(path);
      output.writeAsStringSync(encoded);
      exports.add({
        'mode': mode.name,
        'records': values.length,
        'path': output.path,
        'bytes': utf8.encode(encoded).length,
        'SHA256': sha256.convert(utf8.encode(encoded)).toString(),
        'fullDocumentDeepEqual': true,
      });
    }
    fixtureOutputFile(
      '$folder/actual-three-mode-full-drive-validation.json',
    ).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(exports)}\n',
    );
  });
}
