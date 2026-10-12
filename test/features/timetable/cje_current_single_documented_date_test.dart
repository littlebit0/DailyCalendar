import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/cje-current-single-offering-one-date-valid-status-period-v8b-20261009';
dynamic read(String path) {
  final actual = path.endsWith('/cje-unknown-2026-2.single-date-v8b.json')
      ? 'assets/timetable/cje-unknown-2026-2.json'
      : path;
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'CJE one documented offering date; 371 whole preserved, three mode Drive',
    () {
      final proof = read(
        '$folder/independent-one-date-native-whole-proof.json',
      );
      final priorFile = fixtureFile('$folder/prior372-whole-archive.json');
      expect(
        sha256.convert(priorFile.readAsBytesSync()).toString(),
        proof['baselineSHA256'],
      );
      for (final entry in (proof['sourceInputsSHA256'] as Map).entries) {
        expect(
          sha256
              .convert(fixtureFile(entry.key as String).readAsBytesSync())
              .toString(),
          entry.value,
        );
      }
      final prior = read(priorFile.path);
      final raw = read('$folder/cje-unknown-2026-2.single-date-v8b.json');
      final courses = raw['courses'] as List;
      final previous = prior['courses'] as List;
      expect(courses, hasLength(372));
      expect(courses.map((c) => c['sourceId']).toSet(), hasLength(372));
      var unchanged = 0;
      for (var i = 0; i < courses.length; i++) {
        final current = Map<String, dynamic>.from(courses[i] as Map);
        if (current['sourceId'] != proof['sourceId']) {
          expect(current, previous[i]);
          unchanged++;
          continue;
        }
        expect(previous[i], proof['priorTargetWhole']);
        final archived = current['previousResearchAnnotation'] as Map;
        for (final key in ['remarks', 'scheduleStatus', 'scheduleHoldReason']) {
          expect(archived[key], previous[i][key]);
          current[key] = archived[key];
        }
        current['schedules'] = previous[i]['schedules'];
        current.remove('previousResearchAnnotation');
        current.remove('period');
        current.remove('evidenceKind');
        current.remove('sourcePeriodScopeSingleKnownDate');
        expect(current, previous[i]);
      }
      expect(unchanged, 371);
      final target = courses.singleWhere(
        (c) => c['sourceId'] == proof['sourceId'],
      );
      expect(target['courseCode'], '');
      expect(target['section'], '');
      expect(target['campus'], 'unknown');
      expect(target['professor'], '이효성/한정혜');
      expect(target['sourceClassroom'], '정305');
      expect(target['scheduleStatus'], 'scheduled');
      expect(target['period'], {
        'startDate': '2026-09-08',
        'endDate': '2026-09-08',
      });
      expect(target['sourcePeriodScopeSingleKnownDate'], true);
      final meeting = (target['schedules'] as List).single as Map;
      expect(meeting['date'], '2026-09-08');
      expect(meeting['weekday'], 2);
      expect(DateTime.parse(meeting['date'] as String).weekday, 2);
      expect(meeting['startMinute'], 16 * 60 + 10);
      expect(meeting['endMinute'], 18 * 60);
      expect(meeting['originalStartMinute'], 970);
      expect(meeting['originalEndMinute'], 1080);
      expect(meeting['classroom'], '정305');
      expect(meeting.containsKey('deliveryMode'), false);
      final model = UniversityDataset.fromJson(raw);
      expect(model.courses, hasLength(372));
      final scheduled = model.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(scheduled, hasLength(1));
      expect(scheduled.single.meetings, hasLength(1));
      expect(scheduled.single.period!.contains(DateTime(2026, 9, 8)), true);
      expect(scheduled.single.period!.contains(DateTime(2026, 9, 7)), false);
      expect(scheduled.single.period!.contains(DateTime(2026, 9, 9)), false);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
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
        expect(restored, hasLength(1));
        expect(
          restored.single.toJson()..remove('id'),
          classes.single.toJson()..remove('id'),
        );
        expect(restored.single.isValid, true);
        expect(restored.single.period!.toJson(), {
          'startDate': '2026-09-08',
          'endDate': '2026-09-08',
        });
        expect(restored.single.period!.contains(DateTime(2026, 9, 15)), false);
        expect(
          restored.single.modeOn(
            restored.single.meetings.single,
            DateTime(2026, 9, 8),
          ),
          mode,
        );
      }
      expect(raw['researchOnly'], false);
      expect(raw['productionIntegrationEnabled'], true);
      expect(raw['completionClaim'], false);
    },
  );
}
