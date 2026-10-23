import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'KU144 exact researcher-note correction preserves school restrictions and actual notes through Drive',
    () {
      const root =
          'work/university-research/catalog-r/ku/remarkful-own-clock-reviewed-v10-20261009';
      final packet =
          jsonDecode(
                fixtureFile(
                  '$root/exact-generated-warning-correction-packet.json',
                ).readAsStringSync(),
              )
              as Map;
      final changes = {for (final r in packet['records']) r['sourceId']: r};
      expect(changes, hasLength(144));
      var checked = 0;
      final selected = <TimetableClass>[];
      for (final campus in ['seoul', 'sejong']) {
        final source =
            jsonDecode(
                  fixtureFile(
                    '$root/korea-$campus-2026-2.remarkful-own-clock-v10.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/korea-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final old = {for (final c in source['courses']) c['sourceId']: c};
        final model = UniversityDataset.fromJson(raw);
        for (final row in raw['courses']) {
          final before = Map<String, dynamic>.from(old[row['sourceId']] as Map);
          if (before['metadata']?.containsKey('researchOnly') == true) {
            before['metadata']['researchOnly'] = false;
          }
          final record = changes[row['sourceId']];
          if (record == null) {
            expect(row, before);
            continue;
          }
          checked++;
          expect(row['previousResearchRemarks'], record['originalRemarks']);
          expect(row['remarks'], record['correctedRemarks']);
          final restored = Map<String, dynamic>.from(row as Map);
          restored['remarks'] = restored.remove('previousResearchRemarks');
          expect(restored, before, reason: row['sourceId']);
          final c = model.courses.singleWhere(
            (c) => c.sourceId == row['sourceId'],
          );
          for (final mode in [
            LectureMode.inPerson,
            LectureMode.liveOnline,
            LectureMode.video,
          ]) {
            final timetable = c.toTimetable(
              id: '${c.sourceId}/${mode.name}',
              mode: mode,
            );
            expect(timetable.note, row['remarks']);
            selected.add(timetable);
          }
        }
      }
      expect(checked, 144);
      // A separate document for each mode avoids duplicate source identities.
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = selected.where((c) => c.defaultMode == mode).toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(144));
        final original = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.note, original[c.sourceId]!.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original[c.sourceId]!.meetings.map((m) => m.toJson()).toList(),
          );
        }
      }
    },
  );
}
