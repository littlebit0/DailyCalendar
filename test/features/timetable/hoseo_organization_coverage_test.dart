import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Hoseo bundled 2026-2 datasets keep every official row affiliated',
    () async {
      final catalog = await UniversityCatalog.load();
      final datasets = catalog.where((d) => d.universityId == 'hoseo').toList();
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'asan': 43, 'cheonan': 39, 'unknown': 2417},
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2499));
      final raw = <String>{};
      final orphans = <String>{};
      for (final course in courses) {
        for (final label in course.departments) {
          if (course.isMajorForSourceDepartment(label) &&
              !course.offeringOrganizations.any(
                (o) => o.sourceLabel == label,
              )) {
            raw.add('${course.campus} $label');
          }
        }
        for (final o in course.offeringOrganizations) {
          if (o.department != null &&
              o.college == null &&
              o.group == null &&
              course.isMajorForOrganization(o)) {
            orphans.add('${course.campus} ${o.department}');
          }
        }
      }
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
      // Booklet p.152 table (09:00 + 60 min x period). A period slot is class
      // 50 min + break 10 min = 60 min (시행규칙 제44조); consecutive periods
      // form one block (0교시~3교시 = 09:00-13:00).
      final zeroToThree = courses.firstWhere((c) => c.sourceSchedule == '월0~3');
      expect(zeroToThree.scheduleStatus, 'scheduled');
      expect(zeroToThree.meetings.first.originalStartMinute, 540);
      expect(zeroToThree.meetings.first.originalEndMinute, 780);
      var checked = 0;
      for (final c in courses.where((c) => c.scheduleStatus == 'scheduled')) {
        final byDay = <int, List<List<int>>>{};
        for (final m in RegExp(
          r'([월화수목금])(\d+)(?:~(\d+))?',
        ).allMatches(c.sourceSchedule)) {
          final a = int.parse(m[2]!);
          byDay.putIfAbsent('월화수목금'.indexOf(m[1]!) + 1, () => []).add([
            a,
            int.parse(m[3] ?? m[2]!),
          ]);
        }
        final expected = <String>{};
        byDay.forEach((day, segs) {
          segs.sort((x, y) => x[0].compareTo(y[0]));
          final merged = <List<int>>[];
          for (final s in segs) {
            if (merged.isNotEmpty && s[0] <= merged.last[1] + 1) {
              if (s[1] > merged.last[1]) merged.last[1] = s[1];
            } else {
              merged.add([...s]);
            }
          }
          for (final s in merged) {
            expected.add('$day/${540 + 60 * s[0]}/${600 + 60 * s[1]}');
          }
        });
        final actual = {
          for (final m in c.meetings)
            '${DateTime.parse(m.date!).weekday}/${m.originalStartMinute}/${m.originalEndMinute}',
        };
        expect(actual, expected, reason: c.sourceId);
        checked++;
      }
      expect(checked, 1743);
      // Still held (remote/hybrid delivery, Saturday, evening-division,
      // conflicting rows); search stays suspended.
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(756),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
