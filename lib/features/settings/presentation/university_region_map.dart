import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/academic/university_regions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';

/// Fits the complete outline. Offshore distances are compressed, while island
/// shapes retain the mainland scale. No scrolling, labels or enlarged insets.
class UniversityMapProjection {
  UniversityMapProjection(Size size) {
    // Longitude scaled by cos(36deg); keep the same metric scale in both axes.
    const width = (129.9 - westBound) * longitudeFactor;
    const height = 38.62 - 33.19;
    scale = math.max(
      0,
      math.min((size.width - 12) / width, (size.height - 12) / height),
    );
    origin = Offset(
      (size.width - width * scale) / 2,
      (size.height - height * scale) / 2,
    );
  }
  static const longitudeFactor = .8090169943749475;
  static const westBound = 125.75;
  static const aspectRatio =
      (129.9 - westBound) * longitudeFactor / (38.62 - 33.19);

  /// Translate distant western island rings as a whole, preserving their shape.
  List<Offset> projectRing(List<Offset> ring) {
    if (ring.isEmpty) return const [];
    final maxLongitude = ring.map((p) => p.dx).reduce(math.max);
    final minLatitude = ring.map((p) => p.dy).reduce(math.min);
    final shift = minLatitude > 34 && maxLongitude < 125
        ? 1.4
        : minLatitude > 34 && maxLongitude < 125.75
        ? .7
        : 0.0;
    return ring.map((p) => project(Offset(p.dx + shift, p.dy))).toList();
  }

  late final double scale;
  late final Offset origin;
  Offset project(Offset point) {
    // Only open-water distance is shortened; island geometry is translated,
    // never scaled independently from the mainland.
    final longitude = point.dx > 131.5
        ? point.dx - 2.02
        : point.dx > 130
        ? point.dx - 1.20
        : point.dx;
    return origin +
        Offset((longitude - westBound) * longitudeFactor, 38.62 - point.dy) *
            scale;
  }
}

class UniversityRegionMap extends StatelessWidget {
  const UniversityRegionMap({
    super.key,
    required this.data,
    required this.selected,
    required this.onSelected,
  });
  final UniversityRegions data;
  final String? selected;
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('지역 선택'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                key: const ValueKey('university-region-all'),
                onPressed: onSelected == null ? null : () => onSelected!(null),
                child: Text(context.tr('전체')),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final projection = UniversityMapProjection(size);
              final shrink = (projection.scale / 100).clamp(0.0, 1.0);
              final painter = _RegionPainter(
                data,
                selected,
                colors,
                DailyUi.separator(context),
                projection,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onSelected == null
                    ? null
                    : (details) {
                        // The geographic surface remains a target when its compact label is small.
                        for (final region in data.regions) {
                          if (painter
                              .path(region.rings)
                              .contains(details.localPosition)) {
                            onSelected!(region.id);
                            return;
                          }
                        }
                      },
                child: Stack(
                  key: const ValueKey('university-map-surface'),
                  children: [
                    Positioned.fill(child: CustomPaint(painter: painter)),
                    for (final region in data.regions)
                      Positioned.fromRect(
                        rect: regionButtonRect(region, projection),
                        child: Semantics(
                          selected: selected == region.id,
                          child: TextButton(
                            key: ValueKey('university-region-${region.id}'),
                            onPressed: onSelected == null
                                ? null
                                : () => onSelected!(region.id),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: selected == region.id
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHigh,
                              foregroundColor: selected == region.id
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                              side: BorderSide(
                                color: selected == region.id
                                    ? colors.primary
                                    : DailyUi.separator(context),
                                width: .6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5 * shrink),
                              ),
                            ),
                            child: Text(
                              context.tr(region.name),
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 12 * shrink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Centred on the geographic anchor, not a separately positioned callout.
Rect regionButtonRect(
  UniversityRegion region,
  UniversityMapProjection projection,
) {
  final shrink = (projection.scale / 100).clamp(0.0, 1.0);
  return Rect.fromCenter(
    center: projection.project(region.anchor),
    width: (region.name.length * 12 + 10) * shrink,
    height: 24 * shrink,
  );
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(
    this.data,
    this.selected,
    this.colors,
    this.border,
    this.projection,
  );
  final UniversityRegions data;
  final String? selected;
  final ColorScheme colors;
  final Color border;
  final UniversityMapProjection projection;

  Path path(List<List<Offset>> rings) {
    final result = Path()..fillType = PathFillType.evenOdd;
    for (final ring in rings) {
      if (ring.isEmpty) continue;
      final points = projection.projectRing(ring);
      final first = points.first;
      result.moveTo(first.dx, first.dy);
      for (final next in points.skip(1)) {
        result.lineTo(next.dx, next.dy);
      }
      result.close();
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in data.regions) {
      canvas.drawPath(
        path(region.rings),
        Paint()
          ..color = region.id == selected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
      );
    }
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    canvas.drawPath(path(data.outlines), stroke);
    for (final rings in data.islands.values) {
      final outline = path(
        rings,
      ); // Same shape scale as mainland; compressed offshore distance only.
      canvas.drawPath(
        outline,
        Paint()
          ..color = selected == '경북'
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
      );
      canvas.drawPath(outline, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter old) =>
      old.data != data ||
      old.selected != selected ||
      old.colors != colors ||
      old.border != border ||
      old.projection.scale != projection.scale ||
      old.projection.origin != projection.origin;
}
