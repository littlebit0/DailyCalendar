import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

const root = 'work/university-research/catalog-w/yonsei/';
Map<String, dynamic> read(String file) =>
    jsonDecode(File('$root$file').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Yonsei native offering union, closures, category aliases, exact clocks and Drive survive without fabricated operation',
    () {
      final audit = read('candidate-audit-v1.json');
      final clockProof =
          jsonDecode(
                File(
                  '${root}current-native-clock-proof-v1.json',
                ).readAsStringSync(),
              )
              as List;
      final source =
          jsonDecode(
                File(
                  'work/university-research/catalog-d/yonsei-2026-2-public-all.json',
                ).readAsStringSync(),
              )
              as Map;
      final byId = <String, List<Map>>{};
      for (final row in source['records'] as List) {
        final key =
            '${row['sysinstDivCd']}/${row['subjtnb']}/${row['corseDvclsNo']}/${row['prctsCorseDvclsNo']}';
        byId.putIfAbsent(key, () => []).add(row as Map);
      }
      final closed = {
        for (final row in audit['closed'] as List) row['identity'] as String,
      };
      expect(closed, hasLength(216));
      final ids = <String>{};
      final scheduled = <UniversityCourse>[];
      var count = 0;
      for (final item in audit['manifest'] as List) {
        final raw = read(item['file'] as String);
        final dataset = UniversityDataset.fromJson(raw);
        expect(dataset.courses, hasLength(item['courses'] as int));
        expect(raw['completionClaim'], false);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = raw['courses'][i] as Map;
          final education = (r['sourceEducation'] as List).cast<Map>();
          final first = education.first;
          final key =
              '${first['sysinstDivCd']}/${c.code}/${c.section}/${r['nativePracticumSection']}';
          expect(ids.add(key), true);
          expect(closed, isNot(contains(key)));
          final originals = byId[key]!;
          expect(education, hasLength(originals.length));
          for (var j = 0; j < education.length; j++) {
            for (final entry in education[j].entries) {
              expect(entry.value, originals[j][entry.key]);
            }
          }
          expect(c.title, first['subjtNm']);
          expect(c.professor, first['cgprfNm'] ?? '');
          expect(c.sourceSchedule, first['lctreTimeNm'] ?? '');
          expect(c.sourceClassroom, first['lecrmNm'] ?? '');
          expect(c.credits, (first['cdt'] as num?)?.toDouble());
          expect(
            c.sourceId,
            'yonsei/${first['sysinstDivCd']}/2026-2/${first['subjtnbCorsePrcts']}',
          );
          expect(c.remarks, contains('공개 예약 계획'));
          expect(
            c.departmentClassifications.values.toSet(),
            education
                .where(
                  (e) => e['estblDeprtNm'] != null && e['estblDeprtNm'] != '',
                )
                .map((e) => e['subsrtDivNm'] ?? '')
                .toSet(),
          );
          if (!c.hasSchedulableMeetings) {
            continue;
          }
          scheduled.add(c);
          expect(first['sysinstDivCd'], isIn(['H1', 'H2']));
          expect(first['lessnSessnDivNm'], '학기');
          expect(
            (first['subjtClNm'] as String).trim(),
            isIn(['대면강의', '비대면(실시간)']),
          );
          expect(c.meetings, isNotEmpty);
          final sourceTimes = c.sourceSchedule.split('/');
          final sourceRooms = c.sourceClassroom.split('/');
          final clockRows =
              (clockProof.singleWhere(
                        (p) =>
                            p['campus'] ==
                            (c.campus == 'mirae' ? 'mirae' : 'sinchon'),
                      )['nativeClockRows']
                      as List)
                  .cast<Map>();
          final nativeSlots = <String>{};
          for (var part = 0; part < sourceTimes.length; part++) {
            final room = sourceRooms[sourceRooms.length == 1 ? 0 : part];
            for (final m in RegExp(
              r'([월화수목금토])(\d+(?:,\d+)*)',
            ).allMatches(sourceTimes[part])) {
              final weekday = '월화수목금토'.indexOf(m[1]!) + 1;
              for (final period in m[2]!.split(',').map(int.parse)) {
                final clock = clockRows.singleWhere(
                  (v) => v['period'] == period,
                );
                nativeSlots.add(
                  '$weekday/${clock['startMinute']}/${clock['endMinute']}/$room',
                );
              }
            }
          }
          final actual = <String>{};
          for (final m in c.meetings) {
            count++;
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01') >= 0, true);
            expect(m.date!.compareTo('2026-12-07') <= 0, true);
            expect(
              m.date!.compareTo('2026-10-20') < 0 ||
                  m.date!.compareTo('2026-10-26') > 0,
              true,
            );
            expect({
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            }, isNot(contains(m.date)));
            expect(
              nativeSlots,
              contains(
                '${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              ),
            );
            expect(
              actual.add(
                '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              ),
              true,
            );
          }
          final expected = <String>{};
          for (
            var day = DateTime(2026, 9, 1);
            !day.isAfter(DateTime(2026, 12, 7));
            day = day.add(const Duration(days: 1))
          ) {
            final date = day.toIso8601String().substring(0, 10);
            if ({
                  '2026-09-24',
                  '2026-09-25',
                  '2026-09-26',
                  '2026-10-03',
                  '2026-10-05',
                  '2026-10-09',
                }.contains(date) ||
                (date.compareTo('2026-10-20') >= 0 &&
                    date.compareTo('2026-10-26') <= 0)) {
              continue;
            }
            for (final slot in nativeSlots) {
              final parts = slot.split('/');
              if (int.parse(parts.first) == day.weekday) {
                expected.add('$date/${parts.skip(1).join('/')}');
              }
            }
          }
          expect(actual, expected, reason: c.sourceId);
          for (final slot in nativeSlots) {
            expect(
              c.meetings.any(
                (m) =>
                    '${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}' ==
                    slot,
              ),
              true,
            );
          }
        }
      }
      expect(ids, byId.keys.toSet().difference(closed));
      expect(ids, hasLength(4710));
      expect(scheduled, hasLength(2396));
      expect(count, 83863);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        );
        final back = restored.materializeClasses();
        expect(back, hasLength(classes.length));
        final byKey = {for (final c in classes) timetableCourseSyncKey(c): c};
        for (final c in back) {
          final before = Map<String, dynamic>.from(
            byKey[timetableCourseSyncKey(c)]!.toJson(),
          )..remove('id');
          final after = Map<String, dynamic>.from(c.toJson())..remove('id');
          expect(after, before);
          expect(c.defaultMode, mode);
        }
      }
    },
  );
}
