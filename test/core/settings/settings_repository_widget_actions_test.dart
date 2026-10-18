import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applied widget action tokens persist and stay bounded', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    expect(repository.appliedWidgetActionTokens(), isEmpty);

    await repository.rememberAppliedWidgetActionTokens(['a', 'b']);
    // A new instance stands for an app restart.
    final restarted = SettingsRepository(preferences: preferences);
    expect(restarted.appliedWidgetActionTokens(), {'a', 'b'});

    await restarted.rememberAppliedWidgetActionTokens([
      for (var i = 0; i < 250; i++) 't$i',
    ]);
    final tokens = restarted.appliedWidgetActionTokens();
    expect(tokens.length, 200);
    expect(tokens.contains('a'), isFalse);
    expect(tokens.contains('t249'), isTrue);
  });
}
