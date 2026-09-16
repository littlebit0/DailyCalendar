import 'package:flutter/widgets.dart';

/// Keeps sheet resizing gestures available without letting short lists bounce.
class DaySheetScrollPhysics extends ClampingScrollPhysics {
  const DaySheetScrollPhysics({required this.isCollapsed, super.parent});

  final bool Function() isCollapsed;

  @override
  DaySheetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      DaySheetScrollPhysics(
        isCollapsed: isCollapsed,
        parent: buildParent(ancestor),
      );

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (isCollapsed()) return value - position.pixels;
    return super.applyBoundaryConditions(position, value);
  }
}
