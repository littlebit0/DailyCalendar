import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_directory.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Registry inspection must not access personal events or perform synchronization.
class _UnusedDependencies
    implements EventRepository, EventCommandService, SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected registry side effect: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every calendar-supported campus resolves an installed source', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final unused = _UnusedDependencies();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        eventRepositoryProvider.overrideWithValue(unused),
        eventCommandServiceProvider.overrideWithValue(unused),
        syncServiceProvider.overrideWithValue(unused),
      ],
    );
    addTearDown(container.dispose);
    final service = container.read(academicCalendarServiceProvider);
    final ids = service.sources.map((source) => source.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'Duplicate source identity');
    final directory = UniversityDirectory.fromJson(
      jsonDecode(File('assets/academic/universities.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final university in directory.universities) {
      if (!university.supportsAcademicCalendar) continue;
      final profile = AcademicProfile(
        universityId: university.institutionId,
        universityName: university.institutionName,
        schoolKind: university.kind.name,
        campusId: university.id,
      );
      expect(profile.academicSourceId, isNotNull, reason: university.id);
      expect(
        ids,
        contains(profile.academicSourceId),
        reason: '${university.institutionName} / ${university.id}',
      );
    }
  });
}
