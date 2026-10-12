import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

const root =
    'work/university-research/catalog-r/ku/remarkful-own-clock-reviewed-v10-20261009/';
Map<String, dynamic> read(String name) {
  final actual = name.endsWith('.remarkful-own-clock-v10.json')
      ? 'assets/timetable/${name.split('-2026-2').first}-2026-2.json'
      : '$root$name';
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
    if (c.containsKey('previousResearchRemarks')) {
      c['remarks'] = c.remove('previousResearchRemarks');
    }
  }
  return data;
}

// Independent literal own campus printed regularclock, not candidate-produced segments.
const seoulClock = <int, (int, int)>{
  0: (480, 530),
  1: (540, 615),
  2: (630, 705),
  3: (720, 795),
  4: (810, 885),
  5: (900, 975),
  6: (990, 1065),
  7: (1080, 1130),
  8: (1140, 1190),
  9: (1200, 1250),
  10: (1260, 1310),
};
const publishedRooms = <String, String>{
  'KLLE218-00': '교육관 507호',
  'SPGE225-00': 'SK미래관 김양현홀',
  'SPGE261-00': '아주홀',
  'SPGE262-00': '아주홀',
  'SPGE263-01': '한국일보홀',
  'UNIV402-01': '녹지운동장 트랙',
  'UNIV506-00': 'PBL219(SK미래관)',
};
const holidays = {
  '2026-09-24',
  '2026-09-25',
  '2026-09-26',
  '2026-10-03',
  '2026-10-05',
  '2026-10-09',
};
// Separate weeklyanchor algorithm; no candidate date/segment is usedasexpected.
List<String> ownDates(int weekday) {
  final first = DateTime(2026, 9, 1);
  final anchor = first.add(Duration(days: (weekday - first.weekday + 7) % 7));
  final dates = <String>[];
  for (var week = 0; week < 15; week++) {
    final d = anchor.add(Duration(days: week * 7));
    final ds = d.toIso8601String().substring(0, 10);
    if (ds.compareTo('2026-12-13') > 0 ||
        holidays.contains(ds) ||
        (ds.compareTo('2026-10-20') >= 0 && ds.compareTo('2026-10-26') <= 0)) {
      continue;
    }
    dates.add(ds);
  }
  return dates;
}

void main() {
  test(
    'KU exact current raw79 remarkful ownclock, other5260 preserved and full4173 three-mode Drive',
    () {
      final audit = read(
        'whole-remaining1245-native79-remark-operating-audit.json',
      );
      final native = audit['selectedNativeSources'] as List;
      expect(native, hasLength(79));
      final all = <UniversityCourse>[];
      var newMeetings = 0;
      for (final campus in ['seoul', 'sejong']) {
        final raw = read('korea-$campus-2026-2.remarkful-own-clock-v10.json');
        final prior = read('prior-full-$campus-baseline.json');
        final rows = raw['courses'] as List;
        final old = prior['courses'] as List;
        final selected = native
            .where((x) => (x as Map)['campus'] == campus)
            .toList();
        final ids = selected.map((x) => (x as Map)['sourceId']).toSet();
        expect(selected, hasLength(campus == 'seoul' ? 36 : 43));
        expect(rows, hasLength(campus == 'seoul' ? 3612 : 1727));
        expect(raw['researchOnly'], false);
        expect(raw['completionClaim'], false);
        final dataset = UniversityDataset.fromJson(raw);
        all.addAll(dataset.courses);
        for (var i = 0; i < rows.length; i++) {
          if (!ids.contains((rows[i] as Map)['sourceId'])) {
            expect(rows[i], old[i]);
          }
        }
        for (final record in selected) {
          final proof = record as Map;
          final captures = proof['originalNativeCaptures'] as List;
          final source =
              (captures.first as Map)['originalWholeNativeFields'] as Map;
          final id = proof['sourceId'];
          final row =
              rows.singleWhere((x) => (x as Map)['sourceId'] == id) as Map;
          final c = dataset.courses.singleWhere((x) => x.sourceId == id);
          expect(row['sourceEducationalMetadata'], source);
          expect(source['YEAR'], '2026');
          expect(source['TERM'], '2R');
          expect(source['CAMPUS'], campus == 'seoul' ? '서울' : '세종');
          expect(
            row['sourceOriginalTargetRestrictionRemark'],
            source['APPLY_DEPT'],
          );
          expect(row['personalEnrollmentEligibilityClaim'], false);
          expect(row['remarks'], contains(source['APPLY_DEPT']));
          expect(source['MOOC_YN'], '0');
          expect(source['FLEXIBLE_FR_DT'], '');
          expect(source['FLEXIBLE_TO_DT'], '');
          expect(c.code, source['COUR_CD']);
          expect(c.section, source['COUR_CLS']);
          expect(
            c.title,
            (old.singleWhere((value) => value['sourceId'] == id)
                as Map)['courseName'],
          );
          expect(
            row['sourceEducationalMetadata']['COUR_NM'],
            source['COUR_NM'],
          );
          expect(c.professor, source['PROF_NM']);
          expect(c.campus, campus);
          expect(c.hasSchedulableMeetings, true);
          expect(row['sourceOperatingHolds'], isEmpty);
          final remarkRoom =
              publishedRooms['${source['COUR_CD']}-${source['COUR_CLS']}'] ??
              '';
          expect(row['sourceRemarkPublishedRoomLiteral'], remarkRoom);
          expect(row['sourceRoomUnpublished'], remarkRoom.isEmpty);
          if (remarkRoom.isNotEmpty) {
            expect(source['APPLY_DEPT'], contains(remarkRoom));
          }
          if ((source['COUR_CD'] as String) == 'BUSS166') {
            expect(remarkRoom, isEmpty);
          }
          final literal = <String>{};
          for (final line in (source['TIME_ROOM'] as String).split('\n')) {
            final m = RegExp(
              r'^([월화수목금토일])\(([\d,~\-]+)\)\s*$',
            ).firstMatch(line.trim());
            expect(m, isNotNull);
            final weekday = '월화수목금토일'.indexOf(m!.group(1)!) + 1;
            for (final piece in m.group(2)!.split(',')) {
              final b = piece.split(RegExp(r'[-~]')).map(int.parse).toList();
              for (var p = b.first; p <= b.last; p++) {
                final clock = campus == 'seoul'
                    ? seoulClock[p]!
                    : (480 + p * 60, 530 + p * 60);
                for (final ds in ownDates(weekday)) {
                  literal.add(
                    '$ds|$weekday|${clock.$1}|${clock.$2}|$remarkRoom',
                  );
                }
              }
            }
          }
          final actual = c.meetings
              .map(
                (m) =>
                    '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
              )
              .toSet();
          expect(actual, literal);
          expect(c.meetings.length, literal.length);
          expect(c.meetings.every((m) => m.classroom == remarkRoom), true);
          expect(row['actualAttendanceConfirmed'], false);
          expect(
            (row['schedules'] as List).every(
              (s) => !(s as Map).containsKey('deliveryMode'),
            ),
            true,
          );
          newMeetings += c.meetings.length;
        }
      }
      expect(newMeetings, 1582);
      expect(all, hasLength(5339));
      expect(all.where((c) => c.hasSchedulableMeetings), hasLength(4173));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 126456);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = all
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(4173));
        final by = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final original = by[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, original.title);
          expect(c.professor, original.professor);
          expect(c.note, original.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
