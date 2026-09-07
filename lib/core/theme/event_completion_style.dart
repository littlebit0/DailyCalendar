import 'package:flutter/material.dart';

Color calendarEventAccentColor(
  BuildContext context,
  Color categoryColor, {
  required bool completed,
}) {
  return categoryColor;
}

Color calendarEventBackgroundColor(
  BuildContext context,
  Color categoryColor, {
  required bool completed,
  double categoryAlpha = 0.12,
}) {
  return categoryColor.withValues(alpha: categoryAlpha);
}

TextStyle calendarEventCompletionStyle(
  BuildContext context,
  TextStyle? base, {
  required bool completed,
  required Color eventColor,
}) {
  final style = (base ?? const TextStyle()).copyWith(color: eventColor);
  if (!completed) {
    return style;
  }
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final strikeColor = theme.colorScheme.onSurface.withValues(
    alpha: dark ? 0.98 : 0.90,
  );
  return style.copyWith(
    decoration: TextDecoration.lineThrough,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: strikeColor,
    decorationThickness: dark ? 1.4 : 1.5,
  );
}
