import 'dart:convert';
import 'dart:io';

import 'package:daily/core/update/update_requirement.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _readNormalized(String path) async {
  return (await File(path).readAsString()).replaceAll('\r\n', '\n');
}

Future<Map<String, String>> _readAppShortcutStrings(String language) async {
  final source = await _readNormalized(
    'apple_siri/$language.lproj/AppShortcuts.strings',
  );
  return {
    for (final match in RegExp(
      r'^"(.+)" = "(.+)";$',
      multiLine: true,
    ).allMatches(source))
      match.group(1)!: match.group(2)!,
  };
}

void main() {
  test(
    'UIKit-hosted wallpaper settings use UIKit activity and preserve privacy',
    () async {
      final source = await _readNormalized(
        'ios/Runner/DailyWallpaperSettingsView.swift',
      );
      expect(source, isNot(contains('@Environment(\\.scenePhase)')));
      expect(
        source,
        contains('UIApplication.shared.applicationState == .active'),
      );
      expect(source, contains('UIApplication.willResignActiveNotification'));
      expect(source, contains('UIApplication.didBecomeActiveNotification'));
      expect(source, contains('UIApplication.didEnterBackgroundNotification'));
      expect(source, contains('.opacity(appIsActive ? 1 : 0)'));
      expect(source, contains('.allowsHitTesting(appIsActive)'));
      expect(source, contains('bool(forKey: "flutter.appLockEnabled")'));
      expect(source, contains('dismiss()'));
    },
  );

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
      // Month labels share the palette they already resolved with the
      // completion modifier instead of solving the same contrast twice.
      expect(
        source,
        contains(
          'category: event.color, backgroundAlpha: 0.18, palette: colors',
        ),
      );
      expect(source, contains('let colors = palette ?? {'));
      // The shared Swift palette is exercised against numeric RGB fixtures and
      // the full colour grid by tool/tests/event_palette_test.swift. This check
      // guards target wiring, rather than freezing a particular drawing syntax.
      for (final project in ['ios', 'macos']) {
        final projectFile = await _readNormalized(
          '$project/Runner.xcodeproj/project.pbxproj',
        );
        expect(projectFile, contains('DailyEventPalette.swift in Sources'));
      }
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
    'Signal bridge answers from its own request, not shared history',
    () async {
      final source = await _readNormalized('apple_siri/DailySiriIntents.swift');
      final bridgeStart = source.indexOf('private func runAvailableSignal(');
      final bridgeEnd = source.indexOf('private func speak(', bridgeStart);
      expect(bridgeStart, isNonNegative);
      expect(bridgeEnd, greaterThan(bridgeStart));
      final bridge = source.substring(bridgeStart, bridgeEnd);

      // The history is redacted for LMS reads and shared with concurrent Siri
      // requests, so the in-app answer must come from this intent's execution.
      expect(bridge, contains('let message = try await intent.execute()'));
      expect(bridge, contains('error as? DailySignalExecutionFailed'));
      expect(bridge, isNot(contains('DailySiriLogStore')));
      expect(source, contains('let message = try await execute()'));
      expect(
        source,
        contains(
          'summary: containsLms ? DailySiriText.lmsReadCompleted : summary,',
        ),
      );
      expect(
        source,
        contains(
          'result: containsLms ? DailySiriText.lmsReadCompleted : result,',
        ),
      );
    },
  );

  test('Siri reads the update requirement Flutter stores', () async {
    final source = await _readNormalized('apple_siri/DailySiriIntents.swift');

    expect(
      source,
      contains('"flutter.${UpdateRequirementController.requiredVersionKey}"'),
    );
    expect(RegExp(r'try requireNoUpdate\(\)').allMatches(source), hasLength(4));
  });

  test(
    'Signal is shipped as an automatically discoverable App Shortcut',
    () async {
      final source = await _readNormalized('apple_siri/DailySiriIntents.swift');

      expect(source, contains('intent: DailySignalCommandIntent()'));
      expect(source, contains('"Run Signal in \\(.applicationName)"'));
      expect(source, contains('shortTitle: "Signal"'));
      // The Korean phrase people already use ships as the ko translation.
      final korean = await _readAppShortcutStrings('ko');
      expect(
        korean[r'Run Signal in ${applicationName}'],
        r'${applicationName}에서 시그널 실행',
      );
      expect(korean[r'${applicationName} Signal'], r'${applicationName} 시그널');
    },
  );

  test('iOS Runner declares its UserDefaults use (#922)', () async {
    final manifest = await _readNormalized('ios/Runner/PrivacyInfo.xcprivacy');
    expect(
      manifest,
      contains('<string>NSPrivacyAccessedAPICategoryUserDefaults</string>'),
    );
    expect(manifest, contains('<string>CA92.1</string>'));
    final project = await _readNormalized(
      'ios/Runner.xcodeproj/project.pbxproj',
    );
    // In the Runner target's Resources phase, so it lands in Runner.app.
    final resources = RegExp(
      r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{.*?files = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;
    expect(resources, contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test(
    'Siri shortcut and intent wording ships in four languages (#958)',
    () async {
      const languages = ['en', 'ko', 'ja', 'zh-Hant'];
      final source = await _readNormalized('apple_siri/DailySiriIntents.swift');
      Future<Map<String, Map<String, String>>> load(String name) async {
        final catalog =
            jsonDecode(await _readNormalized('apple_siri/$name'))
                as Map<String, Object?>;
        expect(catalog['sourceLanguage'], 'en');
        return {
          for (final entry
              in (catalog['strings'] as Map<String, Object?>).entries)
            entry.key: {
              for (final language
                  in ((entry.value as Map)['localizations'] as Map).entries)
                language.key as String:
                    (language.value as Map)['stringUnit']['value'] as String,
            },
        };
      }

      // AppShortcuts.xcstrings needs iOS 17; the app supports iOS 15, so the
      // phrases ship as per-language AppShortcuts.strings.
      final shortcuts = <String, Map<String, String>>{};
      for (final language in languages) {
        for (final entry in (await _readAppShortcutStrings(language)).entries) {
          (shortcuts[entry.key] ??= {})[language] = entry.value;
        }
      }
      final general = await load('Localizable.xcstrings');
      for (final catalog in [shortcuts, general]) {
        for (final entry in catalog.entries) {
          expect(
            entry.value.keys.toSet(),
            languages.toSet(),
            reason: entry.key,
          );
          expect(entry.value['en'], entry.key);
          expect(entry.value.values, everyElement(isNotEmpty));
        }
      }

      // Every phrase and short title in the provider has a catalog entry, and
      // every translated phrase still names the app, or the system drops it.
      final provider = source.substring(
        source.indexOf('struct DailyAppShortcuts: AppShortcutsProvider {'),
        source.indexOf('private struct DailySiriSnippetView'),
      );
      final phrases = RegExp(r'^        "(.+)",$', multiLine: true)
          .allMatches(provider)
          .map(
            (m) => m
                .group(1)!
                .replaceAll(r'\(.applicationName)', r'${applicationName}'),
          )
          .toList();
      final shortTitles = RegExp(
        r'shortTitle: "(.+)"',
      ).allMatches(provider).map((m) => m.group(1)!).toList();
      expect(phrases, hasLength(20));
      expect(shortTitles, hasLength(10));
      // Phrases are looked up in AppShortcuts.strings; shortTitle is a plain
      // LocalizedStringResource, so it resolves from the default Localizable table.
      expect(shortcuts.keys.toSet(), phrases.toSet());
      expect(general.keys.toSet().containsAll(shortTitles), isTrue);
      for (final title in shortTitles) {
        expect(general[title]!.values.toSet().length, greaterThanOrEqualTo(2));
      }
      for (final phrase in phrases) {
        for (final language in languages) {
          expect(
            shortcuts[phrase]![language],
            contains(r'${applicationName}'),
            reason: '$phrase ($language)',
          );
        }
        // A language must not fall back to another language's phrase.
        expect(
          shortcuts[phrase]!.values.toSet().length,
          greaterThanOrEqualTo(2),
        );
      }
      for (final language in languages) {
        final inLanguage = phrases.map((p) => shortcuts[p]![language]).toList();
        expect(inLanguage.toSet(), hasLength(phrases.length), reason: language);
      }

      // Intent names, descriptions and parameter names.
      final titles = [
        ...RegExp(
          r'static var title: LocalizedStringResource = "(.+)"',
        ).allMatches(source).map((m) => m.group(1)!),
        ...RegExp(
          r'IntentDescription\("(.+)"\)',
        ).allMatches(source).map((m) => m.group(1)!),
        ...RegExp(
          r'@Parameter\(\s*title: "([^"]+)"',
        ).allMatches(source).map((m) => m.group(1)!),
      ];
      expect(titles.length, greaterThan(60));
      expect(
        general.keys.toSet().containsAll(titles),
        isTrue,
        reason: '${titles.toSet().difference(general.keys.toSet())}',
      );

      for (final project in [
        'ios/Runner.xcodeproj/project.pbxproj',
        'macos/Runner.xcodeproj/project.pbxproj',
      ]) {
        final pbxproj = await _readNormalized(project);
        expect(pbxproj, contains('AppShortcuts.strings in Resources */,'));
        expect(pbxproj, contains('Localizable.xcstrings in Resources */,'));
      }
    },
  );

  test('macOS permission prompts are localized like the app (#957)', () async {
    const languages = ['en', 'ko', 'ja', 'zh-Hant'];
    final plist = await _readNormalized('macos/Runner/Info.plist');
    final project = await _readNormalized(
      'macos/Runner.xcodeproj/project.pbxproj',
    );
    final usageKeys = RegExp(
      r'<key>(NS\w+UsageDescription)</key>',
    ).allMatches(plist).map((match) => match.group(1)!).toSet();
    expect(usageKeys, {
      'NSLocationUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    });
    expect(project, contains('InfoPlist.strings in Resources'));

    final entry = RegExp(r'^"(\w+)" = "(.+)";$', multiLine: true);
    final texts = <String, Map<String, String>>{};
    for (final language in languages) {
      expect(plist, contains('<string>$language</string>'));
      expect(project, contains('$language.lproj/InfoPlist.strings'));
      final strings = await _readNormalized(
        'macos/Runner/$language.lproj/InfoPlist.strings',
      );
      texts[language] = {
        for (final match in entry.allMatches(strings))
          match.group(1)!: match.group(2)!,
      };
      // Every prompt the app can raise has wording in every language.
      expect(texts[language]!.keys.toSet(), usageKeys, reason: language);
    }
    for (final key in usageKeys) {
      expect(
        {for (final language in languages) texts[language]![key]},
        hasLength(languages.length),
        reason: '$key must not reuse one language for another',
      );
    }

    // The wording matches the iOS prompts for the same permission.
    for (final language in languages) {
      final ios = await _readNormalized(
        'ios/Runner/$language.lproj/InfoPlist.strings',
      );
      for (final key in [
        'NSMicrophoneUsageDescription',
        'NSSpeechRecognitionUsageDescription',
      ]) {
        expect(ios, contains('"$key" = "${texts[language]![key]}";'));
      }
    }
  });
}
