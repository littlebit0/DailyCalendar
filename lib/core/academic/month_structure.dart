/// Confirms a school page lists each month 1-12 exactly once.
///
/// [headings] are the month headings in document order (for example "3월" or
/// "3월 MARCH"). Used only for sources where an empty month is observed to be
/// kept as an empty section, so a missing or repeated month is a damaged page.
void requireTwelveMonths(Iterable<String> headings, String source) {
  final months = <int>[];
  for (final heading in headings) {
    final match = RegExp(r'^\s*(\d{1,2})\s*월').firstMatch(heading);
    final month = match == null ? null : int.parse(match.group(1)!);
    if (month == null || month < 1 || month > 12) {
      throw FormatException('Invalid $source month heading');
    }
    months.add(month);
  }
  if (months.length != 12 || months.toSet().length != 12) {
    throw FormatException('Incomplete $source month structure');
  }
}
