import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/date_time_patterns.dart';
import 'package:intl/intl.dart';

/// Makes `zh-Hant` / `zh_Hant` format dates with Traditional Chinese symbols.
///
/// The app locale is `zh` + `Hant` with no region. intl has no `zh_Hant` date
/// data, so every `DateFormat` (the app's own and the Material date picker's)
/// fell back to `zh`, which is Simplified ("周一" instead of "週一"). Registering
/// the Taiwan data under `zh_Hant` fixes all of them at once.
///
/// Call after `initializeDateFormatting`.
void registerTraditionalChineseDateSymbols() {
  final symbols = DateFormat.E('zh_TW').dateSymbols.serializeToMap()
    ..['NAME'] = 'zh_Hant';
  initializeDateFormattingCustom(
    locale: 'zh_Hant',
    symbols: DateSymbols.deserializeFromMap(symbols),
    patterns: dateTimePatternMap()['zh_TW'],
  );
}
