import 'package:daily/core/localization/traditional_chinese_date_symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  final monday = DateTime(2026, 11, 16);

  test('zh-Hant dates use Traditional Chinese symbols', () async {
    await initializeDateFormatting();
    final before = {
      for (final locale in ['ko', 'en', 'ja', 'zh', 'zh_TW'])
        locale: DateFormat.yMMMMEEEEd(locale).add_jm().format(monday),
    };
    // The bug this guards against: no zh_Hant data, so zh (Simplified) is used.
    expect(DateFormat.E(zhHant.toLanguageTag()).format(monday), '周一');

    registerTraditionalChineseDateSymbols();

    // Both spellings used by the app's DateFormat call sites.
    expect(DateFormat.E(zhHant.toLanguageTag()).format(monday), '週一');
    expect(DateFormat.E(zhHant.toString()).format(monday), '週一');
    expect(
      DateFormat.yMMMMEEEEd('zh-Hant').add_jm().format(monday),
      before['zh_TW'],
    );
    for (final entry in before.entries) {
      expect(
        DateFormat.yMMMMEEEEd(entry.key).add_jm().format(monday),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('Material date picker text is Traditional in zh-Hant', () async {
    await initializeDateFormatting();
    registerTraditionalChineseDateSymbols();
    final material = await GlobalMaterialLocalizations.delegate.load(zhHant);
    expect(material.formatMediumDate(monday), contains('週一'));
    expect(material.formatFullDate(monday), contains('星期一'));
  });
}
