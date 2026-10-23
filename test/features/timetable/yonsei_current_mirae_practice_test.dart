import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-c/yonsei-mirae-parenthesis-v2-20261009/';
Map<String, dynamic> read(String file) {
  if (file.startsWith('yonsei-') && file.contains('.published-partial-v2-')) {
    final campus = file.split('-')[1];
    if (campus == 'international' || campus == 'sinchon' || campus == 'mirae') {
      final frozen =
          jsonDecode(fixtureFile('$root$file').readAsStringSync())
              as Map<String, dynamic>;
      for (final row in frozen['courses']) {
        if (row['metadata']?.containsKey('researchOnly') == true) {
          row['metadata']['researchOnly'] = false;
        }
      }
      return frozen;
    }
    // The frozen v2 unknown-campus candidate is byte-identical to its v1
    // baseline; the live asset has since been rechecked against the portal.
    file = 'baseline-yonsei-unknown-v1.json';
  }
  final frozen =
      jsonDecode(fixtureFile('$root$file').readAsStringSync())
          as Map<String, dynamic>;
  if (file.startsWith('baseline-yonsei-')) {
    for (final row in frozen['courses']) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
  }
  return frozen;
}

const campuses = ['sinchon', 'international', 'mirae', 'unknown'];
List<Map> rows(String campus, bool baseline) =>
    (read(
              baseline
                  ? 'baseline-yonsei-$campus-v1.json'
                  : 'yonsei-$campus-2026-2.published-partial-v2-20261009.json',
            )['courses']
            as List)
        .cast<Map>();
List<(String, String)> sourceGroups(String text) {
  final result = <(String, String)>[];
  var buffer = '';
  var practice = false;
  for (final char in text.split('')) {
    if (char == '(' || char == ')') {
      if (buffer.isNotEmpty) {
        result.add((practice ? 'practice' : 'lecture', buffer));
        buffer = '';
      }
      expect(practice, char == ')', reason: text);
      practice = char == '(';
    } else {
      buffer += char;
    }
  }
  expect(practice, false);
  if (buffer.isNotEmpty) {
    result.add(('lecture', buffer));
  }
  return result;
}

Set<String> nativeSlots(Map row, List<Map> clocks) {
  final timeParts = (row['sourceSchedule'] as String).split('/');
  final roomParts = (row['sourceClassroom'] as String).split('/');
  expect(roomParts.length == 1 || roomParts.length == timeParts.length, true);
  final result = <String>{};
  for (var i = 0; i < timeParts.length; i++) {
    final times = sourceGroups(timeParts[i].replaceAll(RegExp(r'\s+'), ''));
    final rooms = sourceGroups(roomParts[roomParts.length == 1 ? 0 : i]);
    final shared = rooms.length == 1 && rooms.single.$1 == 'lecture';
    if (!shared) {
      expect(rooms.map((g) => g.$1).toList(), times.map((g) => g.$1).toList());
    }
    for (var j = 0; j < times.length; j++) {
      final group = times[j];
      final room = rooms[shared ? 0 : j].$2;
      final matches = RegExp(
        r'([월화수목금토])(\d+(?:,\d+)*)',
      ).allMatches(group.$2).toList();
      expect(matches.map((m) => m[0]).join(','), group.$2);
      for (final match in matches) {
        final weekday = '월화수목금토'.indexOf(match[1]!) + 1;
        for (final p in match[2]!.split(',').map(int.parse)) {
          final clock = clocks.singleWhere((c) => c['period'] == p);
          expect(
            result.add(
              '$weekday/${clock['startMinute']}/${clock['endMinute']}/$room',
            ),
            true,
          );
        }
      }
    }
  }
  return result;
}

void main() {
  final audit = read('candidate-audit-v2.json');
  final newIds = (audit['newNativeProofs'] as List)
      .cast<Map>()
      .map((p) => p['sourceId'] as String)
      .toSet();
  test(
    'whole4710 native metadata and all prior2396 deeply preserved; only324 official Mirae scopes added',
    () {
      final ids = <String>{};
      var prior = 0;
      var priorFrames = 0;
      var changed = 0;
      for (final campus in campuses) {
        final before = rows(campus, true);
        final after = rows(campus, false);
        expect(after.length, before.length);
        for (var i = 0; i < after.length; i++) {
          final b = before[i];
          final c = after[i];
          expect(ids.add(c['sourceId'] as String), true);
          if ((b['schedules'] as List).isNotEmpty) {
            prior++;
            priorFrames += (b['schedules'] as List).length;
          }
          if (!newIds.contains(c['sourceId'])) {
            expect(c, b);
            continue;
          }
          changed++;
          expect(campus, 'mirae');
          expect(b['schedules'], isEmpty);
          for (final entry in b.entries) {
            if (![
              'schedules',
              'scheduleStatus',
              'remarks',
              'departmentRemarks',
            ].contains(entry.key)) {
              expect(c[entry.key], entry.value);
            }
          }
          final native = (c['sourceEducation'] as List).cast<Map>().first;
          expect(native['sysinstDivCd'], 'H2');
          expect(native['campsDivNm'], '미래');
          expect(native['rmvlcYn'], '0');
          expect(native['lessnSessnDivNm'], '학기');
          expect((native['subjtClNm'] as String).trim(), '대면강의');
          expect(
            c['sourceId'],
            'yonsei/H2/2026-2/${native['subjtnbCorsePrcts']}',
          );
          expect(c['remarks'], isNot(contains('일정 보류:')));
        }
      }
      expect(ids.length, 4710);
      final closed =
          (read(
                    'original-closed-native-identity-proof.json',
                  )['closedIdentities']
                  as List)
              .cast<String>()
              .map((k) {
                final parts = k.split('/');
                return 'yonsei/${parts[0]}/2026-2/${parts.skip(1).join('-')}';
              })
              .toSet();
      expect(closed.length, 216);
      expect(ids.intersection(closed), isEmpty);
      expect(ids.union(closed).length, 4926);
      expect(prior, 2396);
      expect(priorFrames, 83863);
      expect(changed, 324);
      final legend = read('current-mirae-official-legend.json');
      expect(legend['scope'], '<미래캠퍼스>');
      expect(legend['currentSemester'], '2026-2');
      expect(legend['sinchonGeneralization'], false);
      expect(
        legend['literal'],
        contains('월1 → 월요일 1교시 강의 / (월1) → 월요일 1교시 실습'),
      );
      final review = read('prior-mirae-parenthesis-structural-review.json');
      expect(
        (review['reviewRows'] as List)
            .where((r) => r['parseResult'] == 'period clock unpublished')
            .length,
        38,
      );
      expect(
        read('new-candidate-private-residual-audit.json')['contactHitCount'],
        0,
      );
    },
  );
  test(
    'each new324 native lecture/practice/room and own-term complete dates independently match',
    () {
      final clockProof =
          (jsonDecode(
                    fixtureFile(
                      '${root}current-native-clock-proof-v1.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map>();
      final clocks =
          (clockProof.singleWhere(
                    (r) => r['campus'] == 'mirae',
                  )['nativeClockRows']
                  as List)
              .cast<Map>();
      final holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      var frames = 0;
      for (final c in rows(
        'mirae',
        false,
      ).where((c) => newIds.contains(c['sourceId']))) {
        final native = (c['sourceEducation'] as List).cast<Map>();
        for (final alias in native) {
          expect(alias['lctreTimeNm'], c['sourceSchedule']);
          expect(alias['lecrmNm'], c['sourceClassroom']);
        }
        final slots = nativeSlots(c, clocks);
        final expected = <String>{};
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 7));
          date = date.add(const Duration(days: 1))
        ) {
          final key = date.toIso8601String().substring(0, 10);
          if (holidays.contains(key) ||
              (key.compareTo('2026-10-20') >= 0 &&
                  key.compareTo('2026-10-26') <= 0)) {
            continue;
          }
          for (final slot in slots) {
            final fields = slot.split('/');
            if (int.parse(fields.first) == date.weekday) {
              expected.add('$key/${fields.skip(1).join('/')}');
            }
          }
        }
        final model = UniversityCourse.fromJson(c.cast<String, dynamic>());
        final actual = <String>{};
        for (final m in model.meetings) {
          frames++;
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(
            actual.add(
              '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: c['sourceId'] as String);
      }
      expect(frames, 13102);
    },
  );
  test(
    'whole2720 offerings three selected modes and full Drive JSON deep roundtrip',
    () {
      final all = <UniversityCourse>[];
      for (final campus in campuses) {
        all.addAll(
          UniversityDataset.fromJson(
            read('yonsei-$campus-2026-2.published-partial-v2-20261009.json'),
          ).courses.where((c) => c.hasSchedulableMeetings),
        );
      }
      expect(all.length, 2720);
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 96965);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = all
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final back = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(back.length, classes.length);
        final before = {for (final c in classes) timetableCourseSyncKey(c): c};
        for (final c in back) {
          final old = Map<String, dynamic>.from(
            before[timetableCourseSyncKey(c)]!.toJson(),
          )..remove('id');
          final now = Map<String, dynamic>.from(c.toJson())..remove('id');
          expect(now, old);
          expect(c.defaultMode, mode);
        }
      }
    },
  );
}
