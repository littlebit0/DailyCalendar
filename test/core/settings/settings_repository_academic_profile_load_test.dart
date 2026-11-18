import 'dart:convert';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'academicProfile.v1';

  Future<SettingsRepository> repositoryWith(Object value) async {
    SharedPreferences.setMockInitialValues({key: value});
    return SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  }

  for (final entry in <String, Object>{
    'unknown schoolKind':
        '{"universityId":"x","universityName":"X","schoolKind":"graduate"}',
    'wrong field type': '{"universityId":1,"universityName":"X"}',
    'damaged JSON': '{"universityId":',
    'non-string value': 7,
  }.entries) {
    test(
      '${entry.key} loads without a profile and keeps the stored value',
      () async {
        final repository = await repositoryWith(entry.value);

        final settings = repository.load();

        expect(settings.academicProfile, isNull);
        await repository.save(
          settings.copyWith(weekStartsOnMonday: !settings.weekStartsOnMonday),
          changedFrom: settings,
        );
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.get(key), entry.value);
      },
    );
  }

  test('a valid stored profile still loads', () async {
    const profile = AcademicProfile(
      universityId: 'x',
      universityName: 'X',
      schoolKind: 'fourYear',
    );
    final repository = await repositoryWith(jsonEncode(profile.toJson()));

    expect(repository.load().academicProfile, profile);
  });
}
