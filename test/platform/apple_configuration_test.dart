import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _readNormalized(String path) async {
  return (await File(path).readAsString()).replaceAll('\r\n', '\n');
}

void main() {
  test('iOS declares why Daily uses Face ID', () async {
    final plist = await _readNormalized('ios/Runner/Info.plist');

    expect(plist, contains('<key>NSFaceIDUsageDescription</key>'));
    expect(plist, contains('Daily 앱 잠금을 안전하게 해제하기 위해 Face ID를 사용합니다.'));
  });

  test('iOS unlocks the full dynamic ProMotion refresh-rate range', () async {
    final plist = await _readNormalized('ios/Runner/Info.plist');

    expect(
      plist,
      contains('<key>CADisableMinimumFrameDurationOnPhone</key>\n\t<true/>'),
    );
  });

  test('Apple runners do not force a fixed application frame rate', () async {
    final sources = await Future.wait([
      _readNormalized('ios/Runner/AppDelegate.swift'),
      _readNormalized('macos/Runner/AppDelegate.swift'),
    ]);
    final runnerSource = sources.join('\n');

    expect(runnerSource, isNot(contains('preferredFramesPerSecond')));
    expect(runnerSource, isNot(contains('preferredFrameRateRange')));
  });

  test(
    'Apple widgets follow Daily theme settings and expose checkbox Todo actions',
    () async {
      final source = await _readNormalized('apple_widgets/DailyWidgets.swift');

      expect(source, contains('@Environment(\\.colorScheme)'));
      expect(source, contains('switch themeMode'));
      expect(source, contains('case "light":'));
      expect(source, contains('case "dark":'));
      expect(source, contains('return systemColorScheme'));
      expect(source, contains('resolvedColorScheme'));
      expect(source, contains('.environment(\\.colorScheme, colorScheme)'));
      expect(source, contains('themeIdentity'));
      expect(source, isNot(contains('.background(background)')));
      expect(source, contains('WidgetCenter.shared.reloadAllTimelines()'));
      expect(source, isNot(contains('reloadTimelines(ofKind:')));
      expect(source, contains('static let today = "DailyTodayWidget"'));
      expect(source, contains('static let calendar = "DailyMonthWidget"'));
      expect(source, contains('static let dday = "DailyDdayWidget"'));
      expect(source, contains('static let dailyText = Color.primary'));
      expect(
        source,
        contains(
          'modifier(DailyWidgetBackgroundModifier(themeMode: themeMode))',
        ),
      );
      expect(
        '.dailyWidgetBackground(themeMode: entry.snapshot.themeMode)'
            .allMatches(source)
            .length,
        4,
      );
      expect(
        source,
        isNot(contains('Color(red: 0.98, green: 0.985, blue: 1.0)')),
      );
      expect(source, contains('private struct DailyTodoToggle: View'));
      expect(source, contains('struct DailyToggleTodoIntent: AppIntent'));
      expect(
        source,
        isNot(contains('private struct DailyToggleTodoIntent: AppIntent')),
      );
      expect(
        source,
        contains('Button(\n        intent: DailyToggleTodoIntent'),
      );
      expect(source, contains('DailyTodoToggle(event: event)'));
      expect(source, contains('.dailyTodoCompletion('));
      expect(source, contains('eventColor: Color.daily(argb: event.color)'));
      expect(source, contains('.foregroundStyle(eventColor)'));
      expect(
        source,
        contains('.strikethrough(true, color: Color.primary.opacity(0.78))'),
      );
      expect(source, isNot(contains('VStack(spacing: 1.5)')));
      expect(source, contains('snapshot["generatedAt"]'));
      expect(source, contains('notifyApp()'));
    },
  );

  test('Daily coalesces rapid Apple widget theme refreshes', () async {
    final sources = await Future.wait([
      _readNormalized('lib/core/widgets/apple_widget_service.dart'),
      _readNormalized('lib/core/widgets/calendar_widget_service.dart'),
      _readNormalized('lib/app/daily_app.dart'),
    ]);
    final serviceSource = '${sources[0]}\n${sources[1]}';
    final appSource = sources[2];

    expect(
      serviceSource,
      contains(
        'Duration themeRefreshDelay = const Duration(milliseconds: 400)',
      ),
    );
    expect(
      serviceSource,
      contains('final generation = ++_themeRefreshGeneration'),
    );
    expect(serviceSource, contains('generation != _themeRefreshGeneration'));
    expect(appSource, contains('previous?.themeMode != next.themeMode'));
    expect(appSource, contains('.refreshTheme().catchError'));
  });

  test('Apple runners receive live widget Todo action signals', () async {
    final sources = await Future.wait([
      _readNormalized('ios/Runner/AppDelegate.swift'),
      _readNormalized('macos/Runner/MainFlutterWindow.swift'),
    ]);

    for (final source in sources) {
      expect(source, contains('todoActionsChanged'));
      expect(source, contains('widgetTodoActionsChanged'));
      expect(source, contains('WidgetCenter.shared.reloadAllTimelines()'));
      expect(source, isNot(contains('reloadTimelines(ofKind:')));
    }
  });

  test(
    'Signal is shipped as an automatically discoverable App Shortcut',
    () async {
      final source = await _readNormalized('apple_siri/DailySiriIntents.swift');

      expect(source, contains('intent: DailySignalCommandIntent()'));
      expect(source, contains('"\\(.applicationName)에서 시그널 실행"'));
      expect(source, contains('shortTitle: "Signal"'));
    },
  );
}
