import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maximizes the weaker contrast against both the title and its background.
/// Contrast depends only on luminance: extrema are black, white and the
/// geometric midpoint of the two adjusted luminances.
Color calendarEventStrikeColor(Color text, Color background) {
  final bg = Color.alphaBlend(background, Colors.white);
  final ink = Color.alphaBlend(text, bg);
  final a = ink.computeLuminance() + 0.05;
  final b = bg.computeLuminance() + 0.05;
  final midpoint = math.sqrt(a * b) - 0.05;
  final srgb = midpoint <= 0.0031308
      ? midpoint * 12.92
      : 1.055 * math.pow(midpoint, 1 / 2.4) - 0.055;
  final channel = (srgb * 255).round().clamp(0, 255);
  var best = Colors.black;
  var bestScore = 0.0;
  for (final c in {
    0,
    255,
    channel,
    (channel - 1).clamp(0, 255),
    (channel + 1).clamp(0, 255),
  }) {
    final color = Color.fromARGB(255, c, c, c);
    final l = color.computeLuminance() + 0.05;
    final score = math.min(
      math.max(l, a) / math.min(l, a),
      math.max(l, b) / math.min(l, b),
    );
    if (score > bestScore) {
      best = color;
      bestScore = score;
    }
  }
  return best;
}

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
  return categoryColor.withValues(alpha: categoryAlpha);
}

TextStyle calendarEventCompletionStyle(
  BuildContext context,
  TextStyle? base, {
  required bool completed,
  required Color eventColor,
  Color? backgroundColor,
}) {
  final style = (base ?? const TextStyle()).copyWith(color: eventColor);
  if (!completed) {
    return style;
  }
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final strikeColor = calendarEventStrikeColor(
    eventColor,
    _eventSurface(context, backgroundColor),
  );
  return style.copyWith(
    decoration: TextDecoration.lineThrough,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: strikeColor,
    decorationThickness: dark ? 1.4 : 1.5,
  );
}
