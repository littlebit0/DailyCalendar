import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Display colours only: the stored category and its identifying accent stay
/// unchanged. Both states use the same title, so completing it cannot hide it.
class CalendarEventPalette {
  const CalendarEventPalette(this.foreground, this.strike, this.background);

  final Color foreground;
  final Color strike;
  final Color background;
}

final _paletteCache = <(int, int), CalendarEventPalette>{};

/// Resolves an opaque, actually painted surface before selecting title/line ink.
/// Targets are title/background >= 4.5 and line/title/background >= 3.
/// A single line cannot meet both constraints on every fixed background. Only
/// when necessary, project that surface to the nearest feasible luminance too.
/// All projections mix the original RGB towards black/white (same RGB hue),
/// never a table of selected colours or RGB cutoffs.
CalendarEventPalette calendarEventPalette(Color category, Color background) {
  final bg = Color(
    Color.alphaBlend(background, const Color(0xffffffff)).toARGB32(),
  );
  final source = Color(Color.alphaBlend(category, bg).toARGB32());
  final key = (source.toARGB32(), bg.toARGB32());
  final cached = _paletteCache.remove(key);
  if (cached != null) {
    _paletteCache[key] = cached;
    return cached;
  }
  var result = _onSurface(source, bg);
  if (result == null) {
    // Feasible surface intervals follow from the three contrast inequalities.
    // Margins leave room for 8-bit quantisation; final colours are rechecked.
    const q = _titleTarget;
    const s = _strikeTarget;
    final ranges = [
      _Range(.05, 1.05 / (s * s)),
      _Range(.05 * s, 1.05 / q),
      _Range(.05 * q, 1.05 / s),
      _Range(.05 * s * s, 1.05),
    ];
    var distance = double.infinity;
    for (final range in ranges) {
      for (final candidate in _coloursInRange(bg, range)) {
        final palette = _onSurface(source, candidate);
        if (palette == null) continue;
        final delta = _distance(bg, candidate);
        if (delta < distance) {
          distance = delta;
          result = palette;
        }
      }
    }
  }
  // Black/white endpoints are in the feasible intervals above, including after
  // quantisation. A missing result is an implementation error, not a silent
  // fallback to an unreadable category colour.
  if (result == null) throw StateError('No accessible event palette');
  _paletteCache[key] = result;
  if (_paletteCache.length > 512) {
    _paletteCache.remove(_paletteCache.keys.first);
  }
  return result;
}

const _titleTarget = 4.55;
const _strikeTarget = 3.05;

final _linear = List<double>.generate(256, (channel) {
  final value = channel / 255;
  return value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
});
double _light(Color color) {
  final rgb = color.toARGB32();
  return .2126 * _linear[(rgb >> 16) & 255] +
      .7152 * _linear[(rgb >> 8) & 255] +
      .0722 * _linear[rgb & 255] +
      .05;
}

double calendarEventContrast(Color a, Color b) {
  final x = _light(a), y = _light(b);
  return math.max(x, y) / math.min(x, y);
}

class _Range {
  const _Range(this.low, this.high);
  final double low;
  final double high;
}

List<_Range> _contrastRanges(double light, double ratio) => [
  _Range(.05, light / ratio),
  _Range(light * ratio, 1.05),
];

Iterable<_Range> _intersections(List<_Range> a, List<_Range> b) sync* {
  for (final x in a) {
    for (final y in b) {
      final low = math.max(.05, math.max(x.low, y.low));
      final high = math.min(1.05, math.min(x.high, y.high));
      if (low <= high) yield _Range(low, high);
    }
  }
}

CalendarEventPalette? _onSurface(Color source, Color background) {
  final b = _light(background);
  const s = _strikeTarget;
  // A line can be below both colours, above both, or between them.
  final withLine = [
    if (b >= .05 * s) const _Range(.05 * s, 1.05),
    if (b <= 1.05 / s) const _Range(.05, 1.05 / s),
    _Range(.05, b / (s * s)),
    _Range(b * s * s, 1.05),
  ];
  CalendarEventPalette? best;
  var distance = double.infinity;
  for (final range in _intersections(
    _contrastRanges(b, _titleTarget),
    withLine,
  )) {
    for (final ink in _coloursInRange(source, range)) {
      final delta = _distance(source, ink);
      if (delta >= distance || calendarEventContrast(ink, background) < 4.5) {
        continue;
      }
      final line = _line(source, ink, background);
      if (line == null) continue;
      best = CalendarEventPalette(ink, line, background);
      distance = delta;
      if (distance == 0) return best;
      break;
    }
  }
  return best;
}

Color? _line(Color source, Color ink, Color background) {
  final a = _light(ink), b = _light(background);
  Color? best;
  var score = double.infinity;
  // Prefer a line between title and surface luminance when possible, avoiding
  // a glaring brighter-than-both line. Its hue remains the category's hue.
  for (final range in _intersections(
    _contrastRanges(a, _strikeTarget),
    _contrastRanges(b, _strikeTarget),
  )) {
    final preferred = math.sqrt(a * b).clamp(range.low, range.high);
    for (final line in _coloursInRange(source, range, preferred: preferred)) {
      if (calendarEventContrast(line, ink) < 3 ||
          calendarEventContrast(line, background) < 3) {
        continue;
      }
      final l = _light(line);
      final outside = l < math.min(a, b) || l > math.max(a, b);
      final candidateScore =
          (outside ? 10 : 0) + (math.log(l / preferred)).abs();
      if (candidateScore < score) {
        score = candidateScore;
        best = line;
      }
      break;
    }
  }
  return best;
}

Iterable<Color> _coloursInRange(
  Color source,
  _Range range, {
  double? preferred,
}) sync* {
  final target = (preferred ?? _light(source)).clamp(range.low, range.high);
  final center = (range.low + range.high) / 2;
  final seen = <int>{};
  // Move inward only if rounded colours at a boundary do not meet the target.
  for (final step in [0.0, .0625, .125, .25, .5, 1.0]) {
    final color = _withLight(source, target + (center - target) * step);
    if (seen.add(color.toARGB32())) yield color;
  }
}

Color _withLight(Color source, double light) {
  if ((_light(source) - light).abs() < 1e-12) return source;
  final white = light > _light(source);
  final rgb = source.toARGB32();
  final r = (rgb >> 16) & 255, g = (rgb >> 8) & 255, b = rgb & 255;
  final end = white ? 255 : 0;
  double low = 0, high = 1;
  double lightAt(double t) =>
      .2126 * _linear[(r + (end - r) * t).round()] +
      .7152 * _linear[(g + (end - g) * t).round()] +
      .0722 * _linear[(b + (end - b) * t).round()] +
      .05;
  for (var i = 0; i < 20; i++) {
    final mid = (low + high) / 2;
    if ((lightAt(mid) < light) == white) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return Color.fromARGB(
    255,
    (r + (end - r) * high).round(),
    (g + (end - g) * high).round(),
    (b + (end - b) * high).round(),
  );
}

double _distance(Color a, Color b) =>
    math.pow(a.r - b.r, 2).toDouble() +
    math.pow(a.g - b.g, 2).toDouble() +
    math.pow(a.b - b.b, 2).toDouble();
