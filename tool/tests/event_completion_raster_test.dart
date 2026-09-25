// Manual real-font audit; fails explicitly if the supplied font files are absent.
// FLUTTER_ROOT=... tool/flutter.sh test --no-pub tool/tests/event_completion_raster_test.dart
// Override DAILY_AUDIT_KOREAN_FONT / DAILY_AUDIT_LATIN_FONT on other hosts.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/theme/event_completion_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _korean = 'DailyAuditKorean';
const _latin = 'DailyAuditLatin';
const _output = 'work/issue81-full-rgb';
const _representatives = <String, Color>{
  'Black': Color(0xff000000),
  'White': Color(0xffffffff),
  'Yellow': Color(0xffffff00),
  'Orange': Color(0xffff9800),
  'Red': Color(0xffef4444),
  'Blue': Color(0xff2563eb),
  'Green': Color(0xff22c55e),
  'Purple': Color(0xffa855f7),
  'Gray': Color(0xff808080),
  'Blue edge': Color(0xff000aff),
  'Teal edge': Color(0xff28b496),
  'Muted blue': Color(0xff8cb4d2),
};

void main() {
  testWidgets(
    'full RGB real-font strike visibility and title preservation',
    (tester) async {
      final contexts = <String, BuildContext>{};
      const surfaces = <String, Color>{
        'light': Colors.white,
        'dark': Colors.black,
        'light elevated': Color(0xfff0f0f5),
        'dark elevated': Color(0xff252528),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (final surface in surfaces.entries)
                Expanded(
                  child: Theme(
                    data: surface.key.startsWith('dark')
                        ? DailyTheme.dark()
                        : DailyTheme.light(),
                    child: Material(
                      color: surface.value,
                      child: Builder(
                        builder: (context) {
                          contexts[surface.key] = context;
                          return const SizedBox.expand();
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.runAsync(() async {
        final root = Platform.environment['FLUTTER_ROOT'];
        final fontPaths = <String, String>{
          _korean:
              Platform.environment['DAILY_AUDIT_KOREAN_FONT'] ??
              '/System/Library/Fonts/AppleSDGothicNeo.ttc',
          _latin:
              Platform.environment['DAILY_AUDIT_LATIN_FONT'] ??
              '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Medium.ttf',
        };
        for (final entry in fontPaths.entries) {
          final file = File(entry.value);
          if (!file.existsSync()) {
            throw StateError(
              'Required real font missing: ${entry.value}. Set DAILY_AUDIT_KOREAN_FONT / DAILY_AUDIT_LATIN_FONT; this audit must not silently skip.',
            );
          }
          await (FontLoader(
            entry.key,
          )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        await Directory(_output).create(recursive: true);
        final stopwatch = Stopwatch()..start();
        final channels = [...List.generate(26, (index) => index * 10), 255];
        final grid = _Summary();
        final modes = <String, Map<String, Object>>{};
        for (final mode in ['light', 'dark']) {
          final summary = _Summary();
          for (final red in channels) {
            final samples = <_Sample>[
              for (final green in channels)
                for (final blue in channels)
                  _sample(
                    contexts[mode]!,
                    Color.fromARGB(255, red, green, blue),
                    font: _korean,
                    fontSize: 8,
                    dpr: 1,
                    label: '$mode $red,$green,$blue',
                  ),
            ];
            for (final metric in await _auditAtlas(
              samples,
              columns: 27,
              width: 64,
              height: 22,
            )) {
              summary.add(metric);
              grid.add(metric);
            }
          }
          modes[mode] = summary.json;
          // ignore: avoid_print
          print(
            'Full RGB $mode: ${summary.count} actual raster pairs checked.',
          );
        }
        final detailed = <Map<String, Object>>[];
        final representatives = _Summary();
        for (final family in [_korean, _latin]) {
          for (final dpr in [1.0, 2.0, 3.0]) {
            for (final mode in surfaces.keys) {
              final samples = <_Sample>[
                for (final entry in _representatives.entries)
                  for (final size in [8.0, 10.0, 11.0, 14.0, 20.0])
                    _sample(
                      contexts[mode]!,
                      entry.value,
                      font: family,
                      fontSize: size,
                      dpr: dpr,
                      alpha: mode.endsWith('elevated') ? .18 : .15,
                      label: '$mode ${entry.key} $family ${size}pt ${dpr}x',
                    ),
              ];
              for (final metric in await _auditAtlas(
                samples,
                columns: 5,
                width: 230,
                height: 40,
              )) {
                representatives.add(metric);
                detailed.add(metric.json);
              }
            }
          }
        }
        await _comparison(contexts);
        stopwatch.stop();
        final report = <String, Object>{
          'channelValues': channels,
          'rgbColorCount': channels.length * channels.length * channels.length,
          'fullGrid': {
            'font': _korean,
            'fontSize': 8,
            'dpr': 1,
            'tintAlpha': .15,
            'summary': grid.json,
            'modes': modes,
          },
          'representativeSummary': representatives.json,
          'representativeCases': detailed,
          'fonts': fontPaths,
          'acceptance': {
            'minimumChangedColumnCoverage': .9,
            'minimumUnchangedGlyphFraction': .5,
            'minimumGlyphPixels': 8,
            'exactlyOneChangedHorizontalBand': true,
            'lineCenterWithinGlyphHeight': [.2, .8],
          },
          'measurement':
              'Actual plain/decorated TextPainter RGBA differences. A changed pixel has RGB L1 distance > 8. Plain glyph mask has RGB L1 distance from its opaque background > 24. Surviving glyph pixels differ by <= 8 after decoration. Coverage uses the laid-out text advance. Edge anti-alias pixels are not WCAG contrast samples.',
          'elapsedSeconds': stopwatch.elapsedMilliseconds / 1000,
          'comparisonPng': '$_output/comparison.png',
        };
        await File(
          '$_output/raster-metrics.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        expect(grid.count, 39366);
        expect(representatives.count, 1440);
        // ignore: avoid_print
        print(
          'Raster audit complete: ${grid.count + representatives.count} pairs, ${stopwatch.elapsedMilliseconds / 1000}s; ${grid.json}',
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

class _Sample {
  const _Sample(this.label, this.text, this.style, this.background, this.dpr);
  final String label;
  final String text;
  final TextStyle style;
  final Color background;
  final double dpr;
}

_Sample _sample(
  BuildContext context,
  Color category, {
  required String font,
  required double fontSize,
  required double dpr,
  required String label,
  double alpha = .15,
}) {
  final background = calendarEventBackgroundColor(
    context,
    category,
    completed: true,
    categoryAlpha: alpha,
  );
  final style = calendarEventCompletionStyle(
    context,
    TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    ),
    completed: true,
    eventColor: category,
    backgroundColor: background,
  );
  expect(style.decoration, TextDecoration.lineThrough, reason: label);
  return _Sample(
    label,
    font == _korean ? '완료 일정' : 'Completed meeting',
    style,
    background,
    dpr,
  );
}

TextPainter _painter(String text, TextStyle style, double width) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout(maxWidth: width);

Future<List<_Metric>> _auditAtlas(
  List<_Sample> samples, {
  required int columns,
  required int width,
  required int height,
}) async {
  final dpr = samples.first.dpr;
  final cellWidth = (width * dpr).round();
  final cellHeight = (height * dpr).round();
  final atlasWidth = cellWidth * columns * 2;
  final atlasHeight = cellHeight * ((samples.length + columns - 1) ~/ columns);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  final textWidths = <double>[];
  for (var i = 0; i < samples.length; i++) {
    final sample = samples[i];
    final x = (i % columns) * width * 2.0;
    final y = (i ~/ columns) * height.toDouble();
    canvas.drawRect(
      Rect.fromLTWH(x, y, width * 2, height.toDouble()),
      Paint()..color = sample.background,
    );
    for (final decorated in [false, true]) {
      final painter = _painter(
        sample.text,
        decorated
            ? sample.style
            : sample.style.copyWith(decoration: TextDecoration.none),
        width - 8,
      );
      if (!decorated) textWidths.add(painter.width);
      expect(painter.didExceedMaxLines, isFalse, reason: sample.label);
      painter.paint(canvas, Offset(x + (decorated ? width : 0) + 4, y + 4));
      painter.dispose();
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(atlasWidth, atlasHeight);
  final data = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final metrics = <_Metric>[];
  for (var i = 0; i < samples.length; i++) {
    final sample = samples[i];
    final bg = sample.background.toARGB32();
    final background = [(bg >> 16) & 255, (bg >> 8) & 255, bg & 255];
    final left = (i % columns) * cellWidth * 2;
    final top = (i ~/ columns) * cellHeight;
    final changedColumns = <int>{};
    final changedRows = <int>{};
    var glyphPixels = 0, survivingGlyphPixels = 0;
    var glyphTop = cellHeight, glyphBottom = -1;
    for (var y = 0; y < cellHeight; y++) {
      for (var x = 0; x < cellWidth; x++) {
        final plain = ((top + y) * atlasWidth + left + x) * 4;
        final decorated = plain + cellWidth * 4;
        var delta = 0, glyphDelta = 0;
        for (var channel = 0; channel < 3; channel++) {
          delta += (data[plain + channel] - data[decorated + channel]).abs();
          glyphDelta += (data[plain + channel] - background[channel]).abs();
        }
        if (delta > 8) {
          changedColumns.add(x);
          changedRows.add(y);
        }
        if (glyphDelta > 24) {
          glyphPixels++;
          glyphTop = math.min(glyphTop, y);
          glyphBottom = math.max(glyphBottom, y);
          if (delta <= 8) survivingGlyphPixels++;
        }
      }
    }
    final rows = changedRows.toList()..sort();
    var bands = 0;
    for (var row = 0; row < rows.length; row++) {
      if (row == 0 || rows[row] != rows[row - 1] + 1) bands++;
    }
    final metric = _Metric(
      sample.label,
      changedColumns.length / (textWidths[i] * dpr).ceil(),
      glyphPixels == 0 ? 0 : survivingGlyphPixels / glyphPixels,
      glyphPixels,
      rows.length,
      bands,
    );
    expect(
      metric.coverage,
      greaterThanOrEqualTo(.9),
      reason: '${sample.label}: line continuity',
    );
    expect(
      metric.survival,
      greaterThanOrEqualTo(.5),
      reason: '${sample.label}: title preservation',
    );
    expect(
      glyphPixels,
      greaterThanOrEqualTo(8),
      reason: '${sample.label}: actual title ink',
    );
    expect(bands, 1, reason: '${sample.label}: exactly one line band');
    final lineCenter = (rows.first + rows.last) / 2;
    expect(
      (lineCenter - glyphTop) / (glyphBottom - glyphTop),
      inInclusiveRange(.2, .8),
      reason:
          '${sample.label}: strike crosses the title, rather than underlining it',
    );
    expect(
      rows.length,
      lessThanOrEqualTo(
        math.max(4, (sample.style.fontSize! * .3 * dpr).ceil()),
      ),
      reason: '${sample.label}: line must not cover title height',
    );
    metrics.add(metric);
  }
  image.dispose();
  picture.dispose();
  return metrics;
}

class _Metric {
  const _Metric(
    this.label,
    this.coverage,
    this.survival,
    this.glyphPixels,
    this.lineRows,
    this.bands,
  );
  final String label;
  final double coverage;
  final double survival;
  final int glyphPixels;
  final int lineRows;
  final int bands;
  Map<String, Object> get json => {
    'case': label,
    'changedColumnCoverage': coverage,
    'unchangedGlyphFraction': survival,
    'glyphPixels': glyphPixels,
    'changedRows': lineRows,
    'horizontalBands': bands,
  };
}

class _Summary {
  int count = 0;
  double coverage = double.infinity, survival = double.infinity;
  int glyphPixels = 1 << 30, lineRows = 0;
  String coverageCase = '', survivalCase = '';
  void add(_Metric metric) {
    count++;
    if (metric.coverage < coverage) {
      coverage = metric.coverage;
      coverageCase = metric.label;
    }
    if (metric.survival < survival) {
      survival = metric.survival;
      survivalCase = metric.label;
    }
    glyphPixels = math.min(glyphPixels, metric.glyphPixels);
    lineRows = math.max(lineRows, metric.lineRows);
  }

  Map<String, Object> get json => {
    'cases': count,
    'minimumChangedColumnCoverage': coverage,
    'minimumUnchangedGlyphFraction': survival,
    'minimumGlyphPixels': glyphPixels,
    'maximumChangedRows': lineRows,
    'coverageWorstCase': coverageCase,
    'preservationWorstCase': survivalCase,
  };
}

Color _legacyStrike(Color text, Color background) {
  final a = text.computeLuminance() + .05,
      b = background.computeLuminance() + .05;
  final middle = math.sqrt(a * b) - .05;
  final encoded = middle <= .0031308
      ? middle * 12.92
      : 1.055 * math.pow(middle, 1 / 2.4) - .055;
  final center = (encoded * 255).round();
  var best = Colors.black, bestScore = 0.0;
  for (final c in {
    0,
    255,
    center,
    math.max(0, center - 1),
    math.min(255, center + 1),
  }) {
    final color = Color.fromARGB(255, c, c, c);
    final l = color.computeLuminance() + .05;
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

Future<void> _comparison(Map<String, BuildContext> contexts) async {
  const width = 1220.0, height = 1070.0, scale = 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xffeeeeef),
  );
  void label(String text, double x, double y, {double size = 14}) {
    final painter = _painter(
      text,
      TextStyle(fontFamily: _latin, fontSize: size, color: Colors.black),
      1200,
    );
    painter.paint(canvas, Offset(x, y));
    painter.dispose();
  }

  label(
    'Daily #81  |  Original RGB display / Adjusted display  |  Actual 10 pt fonts, 2x raster',
    16,
    12,
    size: 20,
  );
  label('LIGHT: original', 154, 50);
  label('LIGHT: adjusted', 412, 50);
  label('DARK: original', 674, 50);
  label('DARK: adjusted', 932, 50);
  var y = 80.0;
  for (final entry in _representatives.entries) {
    label(entry.key, 16, y + 10, size: 13);
    label(
      '#${entry.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      16,
      y + 29,
      size: 12,
    );
    for (final mode in ['light', 'dark']) {
      final modeX = mode == 'light' ? 154.0 : 674.0;
      final oldBg = Color.alphaBlend(
        entry.value.withValues(alpha: .15),
        mode == 'light' ? Colors.white : Colors.black,
      );
      for (final updated in [false, true]) {
        final x = modeX + (updated ? 258 : 0);
        final example = _sample(
          contexts[mode]!,
          entry.value,
          font: _korean,
          fontSize: 10,
          dpr: scale,
          label: entry.key,
        );
        final bg = updated ? example.background : oldBg;
        canvas.drawRect(Rect.fromLTWH(x, y, 248, 70), Paint()..color = bg);
        canvas.drawRect(
          Rect.fromLTWH(x, y, 3, 70),
          Paint()..color = entry.value,
        );
        for (final family in [_korean, _latin]) {
          final style = updated
              ? example.style.copyWith(fontFamily: family)
              : TextStyle(
                  fontFamily: family,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: entry.value,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _legacyStrike(entry.value, oldBg),
                  decorationThickness: mode == 'dark' ? 2.5 : 1.5,
                );
          final painter = _painter(
            family == _korean ? '완료 일정  월간 검토' : 'Completed meeting',
            style,
            230,
          );
          painter.paint(
            canvas,
            Offset(x + 10, y + (family == _korean ? 10 : 31)),
          );
          painter.dispose();
        }
      }
    }
    y += 80;
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * scale).round(),
    (height * scale).round(),
  );
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  await File(
    '$_output/comparison.png',
  ).writeAsBytes(bytes.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}
