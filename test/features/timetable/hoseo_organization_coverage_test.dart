import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Hoseo bundled 2026-2 datasets keep every official row affiliated',
    () async {
      final catalog = await UniversityCatalog.load(university: 'hoseo');
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
          r'([월화수목금토일])(\d+)(?:~(\d+))?',
        ).allMatches(c.sourceSchedule)) {
          final a = int.parse(m[2]!);
          byDay.putIfAbsent('월화수목금토일'.indexOf(m[1]!) + 1, () => []).add([
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
        // 학기종료일(2026-12-18) 뒤에는 수업을 만들지 않는다.
        for (final m in c.meetings) {
          expect(m.date!.compareTo('2026-12-18') <= 0, true, reason: c.sourceId);
        }
        checked++;
      }
      expect(checked, 2450);
      // 2026-11-23 사용자 결정: p.152 교시표를 0~14교시·토·일 강좌 전체에 적용하고
      // 원격·하이브리드 운영도 원문 교시로 확정한다.
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
