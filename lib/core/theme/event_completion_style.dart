import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'event_completion_palette.dart';

export 'event_completion_palette.dart';

/// The line belongs to the resolved display palette, not the raw stored RGB.
Color calendarEventStrikeColor(Color text, Color background) =>
    calendarEventPalette(text, background).strike;

Color _eventSurface(BuildContext context, Color? background) {
  final layers = <Color>[?background];
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is CalendarEventSurface) {
      layers.add(widget.color);
      return false;
    } else if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final color = (widget.decoration as BoxDecoration).color;
      if (color != null) layers.add(color);
    } else if (widget is Material && widget.type != MaterialType.transparency) {
      layers.add(widget.color ?? Theme.of(context).colorScheme.surface);
    }
    return layers.isEmpty || layers.last.a < 1;
  });
  return layers.reversed.fold(
    Theme.of(context).scaffoldBackgroundColor,
    (surface, layer) => Color.alphaBlend(layer, surface),
  );
}

/// Carries the surface below a lifted card into the root drag overlay.
class CalendarEventSurface extends InheritedWidget {
  const CalendarEventSurface({
    super.key,
    required this.color,
    required super.child,
  });
  final Color color;
  static Color of(BuildContext context) => _eventSurface(context, null);
  @override
  bool updateShouldNotify(CalendarEventSurface oldWidget) =>
      oldWidget.color != color;
}

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
  return calendarEventPalette(
    categoryColor,
    _eventSurface(context, categoryColor.withValues(alpha: categoryAlpha)),
  ).background;
}

TextStyle calendarEventCompletionStyle(
  BuildContext context,
  TextStyle? base, {
  required bool completed,
  required Color eventColor,
  Color? backgroundColor,
}) {
  final surface = _eventSurface(context, backgroundColor);
  final palette = calendarEventPalette(eventColor, surface);
  final style = (base ?? const TextStyle()).copyWith(
    color: palette.foreground,
    // Usually the containing card already paints this exact opaque surface.
    // Plain rows need a backing only if their original surface is infeasible.
    backgroundColor: palette.background.toARGB32() == surface.toARGB32()
        ? null
        : palette.background,
  );
  if (!completed) return style;
  final theme = Theme.of(context);
  final fontSize =
      style.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      theme.textTheme.bodyMedium?.fontSize ??
      14;
  return style.copyWith(
    decoration: TextDecoration.lineThrough,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: palette.strike,
    // Flutter multiplies the font's strike metric (about fontSize / 20 in
    // Roboto), not logical pixels. Both themes need at least 1.25 logical
    // pixels at small sizes; scaling keeps one line visible without double ink.
    decorationThickness: math.max(1.5, 25 / fontSize),
  );
}
