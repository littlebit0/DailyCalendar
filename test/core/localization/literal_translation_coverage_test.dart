import 'dart:io';

import 'package:daily/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every Korean string used as the key of a `.tr(…)` call needs a translation
/// in each non-Korean dictionary, or that language silently shows Korean.
///
/// The first argument is scanned as a whole, so string literals chosen by a
/// conditional (`context.tr(done ? '완료' : '미완료')`) are found as well.
///
/// Limits: keys built at run time, adjacent-string concatenation and
/// interpolated strings are not found by this scan.
final _stringLiteral = RegExp(
  r'''\'((?:[^\'\\]|\\.)*)\'|"((?:[^"\\]|\\.)*)"''',
);

/// The text of the first argument of the call whose `(` ends at [start].
String firstArgument(String source, int start) {
  var depth = 0;
  String? quote;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (quote != null) {
      if (char == r'\') {
        index++;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    switch (char) {
      case "'" || '"':
        quote = char;
      case '(' || '[' || '{':
        depth++;
      case ')' || ']' || '}':
        if (depth == 0) return source.substring(start, index);
        depth--;
      case ',':
        if (depth == 0) return source.substring(start, index);
    }
  }
  return source.substring(start);
}

Set<String> translationKeysIn(String source) {
  final keys = <String>{};
  for (final call in RegExp(r'\.tr\(').allMatches(source)) {
    final argument = firstArgument(source, call.end);
    for (final match in _stringLiteral.allMatches(argument)) {
      // A literal followed by `=>` is a switch pattern, not a displayed text.
      if (RegExp(r'^\s*=>').hasMatch(argument.substring(match.end))) continue;
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
  return keys;
}

void main() {
  test('the scan reads literals chosen by a conditional expression', () {
    expect(
      translationKeysIn(
        "a(context.tr(done ? '완료 표시' : \"미완료 표시\"), b: context.tr('고정 키'));",
      ),
      {'완료 표시', '미완료 표시', '고정 키'},
    );
    expect(
      translationKeysIn("context.tr('값: {n}', args: {'n': 1}) + x.tr(name)"),
      {'값: {n}'},
    );
    expect(
      translationKeysIn("context.tr(switch (s) { '여름' => '여름계절학기', _ => '기타' })"),
      {'여름계절학기', '기타'},
    );
  });

  test('literal tr() strings are translated in en, ja and zh', () {
    final keys = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      keys.addAll(translationKeysIn(file.readAsStringSync()));
    }
    expect(keys, isNotEmpty);
    final problems = <String>[];
    for (final locale in const [
      Locale('en'),
      Locale('ja'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      final l10n = AppLocalizations(locale);
      final missing = keys.where((key) => l10n.text(key) == key).toList()
        ..sort();
      if (missing.isNotEmpty) {
        problems.add('${locale.toLanguageTag()} misses $missing');
      }
    }
    expect(problems, isEmpty);
  });

  test('university counts read naturally for one and many in English', () {
    final en = AppLocalizations(const Locale('en'));
    expect(en.text('대학 1개'), '1 university');
    expect(en.text('대학 {count}개', args: {'count': 12}), '12 universities');
  });

  test('terminology stays consistent within the academic-profile flow', () {
    final ja = AppLocalizations(const Locale('ja'));
    final zh = AppLocalizations(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    expect(ja.text('선택한 학사 정보'), contains(ja.text('학사 정보')));
    expect(zh.text('선택한 학사 정보'), contains(zh.text('학사 정보')));
    // Course-offering units, not people who "supervise" (主管).
    for (final key in ['전체 주관', '단과대 주관', '단과대·학과 선택', '단과대 직접 주관 과목', '공개된 학과 주관 정보가 없습니다.']) {
      expect(zh.text(key), isNot(contains('主管')), reason: key);
    }
  });
}
