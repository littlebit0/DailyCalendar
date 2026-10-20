import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// Material localizations that show a 12-hour clock for a locale whose
/// default clock is 24-hour, or null when the locale already uses 12 hours.
///
/// `alwaysUse24HourFormat: false` only keeps the locale default, so Japanese
/// and Traditional Chinese would ignore the app's 12-hour setting without
/// this (flutter/flutter#149179).
MaterialLocalizations? twelveHourMaterialLocalizations(Locale locale) {
  if (locale.languageCode != 'ja' &&
      !(locale.languageCode == 'zh' && locale.scriptCode == 'Hant')) {
    return null;
  }
  final name = Intl.canonicalizedLocale(locale.toString());
  final dateLocale = DateFormat.localeExists(name) ? name : locale.languageCode;
  final numberLocale = NumberFormat.localeExists(name)
      ? name
      : locale.languageCode;
  final fullYearFormat = DateFormat.y(dateLocale);
  final compactDateFormat = DateFormat.yMd(dateLocale);
  final shortDateFormat = DateFormat.yMMMd(dateLocale);
  final mediumDateFormat = DateFormat.MMMEd(dateLocale);
  final longDateFormat = DateFormat.yMMMMEEEEd(dateLocale);
  final yearMonthFormat = DateFormat.yMMMM(dateLocale);
  final shortMonthDayFormat = DateFormat.MMMd(dateLocale);
  final decimalFormat = NumberFormat.decimalPattern(numberLocale);
  final twoDigitZeroPaddedFormat = NumberFormat('00', numberLocale);
  return locale.languageCode == 'ja'
      ? _TwelveHourJa(
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        )
      : _TwelveHourZhHant(
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        );
}

/// Replaces the Material localizations below it with [localizations].
class FixedMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FixedMaterialLocalizationsDelegate(this.localizations);

  final MaterialLocalizations localizations;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(localizations);

  @override
  bool shouldReload(FixedMaterialLocalizationsDelegate old) =>
      old.localizations != localizations;
}

// Both locales put the day period first, as Chinese does ("下午 2:30").
class _TwelveHourJa extends MaterialLocalizationJa {
  const _TwelveHourJa({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.a_space_h_colon_mm;
}

class _TwelveHourZhHant extends MaterialLocalizationZhHant {
  const _TwelveHourZhHant({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.a_space_h_colon_mm;
}
