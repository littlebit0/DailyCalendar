// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/hansung-clock-endpoint-review-v3-20261009/';
  Map<String, dynamic> read(String name) {
    final path = '$root$name';
    final data =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    for (final row in data['courses'] ?? []) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
    return data;
  }

  final prior = read('hansung-frozen-prior-v2-1489.json');
  final raw = read('hansung-main-2026-2.clock-corrected-candidate-v3.json');
  final audit = read('original-PDF-clock-correction-audit.json');
  final dataset = UniversityDataset.fromJson(raw);
  test(
    'only20 native offerings/259 original clock objects corrected; every metadata field/date/room and268holds preserved',
    () {
      expect(raw['courses'], hasLength(1489));
      expect(
        dataset.courses.where((c) => c.meetings.isNotEmpty),
        hasLength(1111),
      );
      expect(audit['actualOriginalLiteral'], ['19:25', '20:40']);
      expect(
        audit['officialOriginalGuideSHA256'],
        'cc07d1b69547aa7aec0f07a0843c366557cc7ebc94aa20b7dca4f3d01d6cbe81',
      );
      final changes = {
        for (final c in audit['affected'] as List) c['sourceId']: c,
      };
      final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
      expect(changes, hasLength(20));
      var changed = 0;
      var starts = 0;
      var ends = 0;
      for (final c in raw['courses'] as List) {
        final expected =
            jsonDecode(jsonEncode(old[c['sourceId']])) as Map<String, dynamic>;
        if (changes.containsKey(c['sourceId'])) {
          for (final change in changes[c['sourceId']]['changes'] as List) {
            final m = expected['schedules'][change['meetingIndex']];
            expect(m['weekday'], 4);
            expect(m['date'], change['date']);
            expect(m['classroom'], change['classroom']);
            for (final e in (change['fields'] as Map).entries) {
              expect(m[e.key], e.value['before']);
              m[e.key] = e.value['after'];
              if (e.key == 'startMinute') {
                starts++;
              } else {
                ends++;
              }
            }
            changed++;
          }
        }
        expect(c, expected);
      }
      expect(changed, 259);
      expect(starts, 117);
      expect(ends, 233);
      expect(
        (raw['courses'] as List).where(
          (c) => c['scheduleStatus'] == 'unrecognized',
        ),
        hasLength(268),
      );
      expect(
        (raw['courses'] as List).where(
          (c) => c['scheduleStatus'] == 'unscheduled',
        ),
        hasLength(110),
      );
    },
  );
  test(
    'all1111 native offerings independently match own originalPDF weekday start/end and room; Thursday literal75min retained',
    () {
      const starts75 = {
        '1': 540,
        '2M': 630,
        '4': 720,
        '5M': 810,
        '7': 900,
        '8M': 990,
        '10': 1080,
        '11M': 1165,
        '13': 1245,
      };
      const ends75 = {
        '2': 615,
        '3M': 705,
        '5': 795,
        '6M': 885,
        '8': 975,
        '9M': 1065,
        '11': 1155,
        '12M': 1240,
        '14': 1320,
      };
      const nightStarts = {10: 1080, 11: 1135, 12: 1190, 13: 1245, 14: 1300};
      const nightEnds = {10: 1130, 11: 1185, 12: 1240, 13: 1295, 14: 1350};
      for (final c in raw['courses'] as List) {
        if ((c['schedules'] as List).isEmpty) {
          continue;
        }
        final slots = <String>{};
        for (final segment in (c['sourceSchedule'] as String).split('/')) {
          if (RegExp(r'^\s*온라인강좌\s+[\d.]+시간\s*$').hasMatch(segment)) {
            continue;
          }
          final r = RegExp(
            r'^\s*(.+?)\s+((?:[월화수목금토일]\d+M?~\d+M?)(?:\s*,\s*[월화수목금토일]\d+M?~\d+M?)*)\s*$',
          ).firstMatch(segment)!;
          final room = r[1]!.trim();
          for (final part in r[2]!.split(',')) {
            final m = RegExp(r'([월화수목금토일])(\d+M?)~(\d+M?)').firstMatch(part)!;
            final day = '월화수목금토일'.indexOf(m[1]!) + 1;
            late int start;
            late int end;
            if ([1, 3, 4].contains(day)) {
              start = starts75[m[2]]!;
              end = ends75[m[3]]!;
            } else {
              expect([2, 5], contains(day));
              final a = int.parse(m[2]!);
              final b = int.parse(m[3]!.replaceAll('M', ''));
              start = a <= 9 ? 540 + (a - 1) * 60 : nightStarts[a]!;
              end = b <= 9 ? 590 + (b - 1) * 60 : nightEnds[b]!;
            }
            slots.add('$day/$start/$end/$room');
          }
        }
        for (final m in c['schedules'] as List) {
          expect(
            slots,
            contains(
              '${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
            ),
          );
        }
      }
      final corrected = dataset.courses.singleWhere(
        (c) => c.sourceId == 'hansung/main/2026/2/P012012/N',
      );
      for (final m in corrected.meetings.where((m) => m.weekday == 4)) {
        expect(m.originalStartMinute, 1165);
        expect(m.originalEndMinute, 1240);
        expect(m.originalEndMinute - m.originalStartMinute, 75);
      }
    },
  );
  test(
    'whole1111/16211 retain every original clock room and educational condition through all3 modes/full Drive JSON',
    () {
      final slots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(slots.fold<int>(0, (n, c) => n + c.meetings.length), 16211);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final original = slots
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: original,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1111));
        expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 16211);
        final map = {for (final c in original) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(
            c.toJson()..remove('id'),
            map[c.sourceId]!.toJson()..remove('id'),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
