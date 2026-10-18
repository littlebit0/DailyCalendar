import 'dart:io';

import 'package:daily/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every Korean string passed straight to `context.tr('…')` needs a translation
/// in each non-Korean dictionary, or that language silently shows Korean.
///
/// Limits: keys built at run time, adjacent-string concatenation and
/// interpolated strings are not found by this scan.
void main() {
  test('literal tr() strings are translated in en, ja and zh', () {
    final pattern = RegExp(
      r'''\.tr\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''',
    );
    final keys = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        final raw = match.group(1) ?? match.group(2)!;
        final key = raw
            .replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n');
        if (RegExp('[가-힣]').hasMatch(key) && !key.contains(r'$')) {
          keys.add(key);
        }
      }
    }
    expect(keys, isNotEmpty);
    for (final locale in const [
      Locale('en'),
      Locale('ja'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      final l10n = AppLocalizations(locale);
      final missing = keys.where((key) => l10n.text(key) == key).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: '${locale.toLanguageTag()} misses $missing',
      );
    }
  });
}
