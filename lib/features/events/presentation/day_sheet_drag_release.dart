import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Thresholds are fractions of the sheet's parent height (and heights per
/// second for velocity), so every screen size gets the same physical feel.
const _belowSmallCloseDistance = 0.12;
const _belowSmallCloseVelocity = 1.2;
const _longDragCloseDistance = 0.4;
const _fastDragCloseDistance = 0.3;
const _fastDragCloseVelocity = 2.0;
const _velocityTolerance = 0.05;

/// Decides where a day sheet should settle when a downward sheet drag ends.
///
/// Returns `0` to close, [smallestStage] to return to the smallest stage, or
/// `null` to keep the sheet's own stage snapping (short drags and upward
/// releases). Sizes are sheet fractions; [downwardVelocity] is parent heights
/// per second, positive when the finger moves down.
double? daySheetReleaseTarget({
  required double startSize,
  required double endSize,
  required double downwardVelocity,
  required double smallestStage,
}) {
  if (downwardVelocity < -_velocityTolerance) return null;
  final travel = startSize - endSize;
  final belowSmall = endSize < smallestStage;
  final close =
      endSize <= smallestStage - _belowSmallCloseDistance ||
      (belowSmall && downwardVelocity >= _belowSmallCloseVelocity) ||
      travel >= _longDragCloseDistance ||
      (travel >= _fastDragCloseDistance &&
          downwardVelocity >= _fastDragCloseVelocity);
  if (close) return 0;
  return belowSmall ? smallestStage : null;
}

/// Lets one long downward drag close a staged [DraggableScrollableSheet]
/// instead of stopping at each stage.
///
/// The sheet must use a `minChildSize` of 0 with `shouldCloseOnMinExtent`, so
/// reaching size 0 closes the hosting bottom sheet.
class DaySheetDragDismissListener extends StatefulWidget {
  const DaySheetDragDismissListener({
    super.key,
    required this.controller,
    required this.smallestStage,
    required this.child,
    this.isSuspended,
  });

  final DraggableScrollableController controller;
  final double smallestStage;

  /// Returns true while another gesture (for example an event drag) owns the
  /// pointer, so the release must not move the sheet.
  final bool Function()? isSuspended;
  final Widget child;

  @override
  State<DaySheetDragDismissListener> createState() =>
      _DaySheetDragDismissListenerState();
}

class _DaySheetDragDismissListenerState
    extends State<DaySheetDragDismissListener> {
  int? _pointer;
  double? _startSize;
  VelocityTracker? _tracker;

  void _handleDown(PointerDownEvent event) {
    if (_pointer != null || !widget.controller.isAttached) {
      // A second finger makes the release ambiguous; leave it to the sheet.
      _pointer = -1;
      return;
    }
    _pointer = event.pointer;
    _startSize = widget.controller.size;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer == _pointer) {
      _tracker?.addPosition(event.timeStamp, event.position);
    }
  }

  void _handleUp(PointerUpEvent event) {
    final pointer = _pointer;
    final startSize = _startSize;
    final tracker = _tracker;
    _reset();
    if (pointer != event.pointer || startSize == null || tracker == null) {
      return;
    }
    tracker.addPosition(event.timeStamp, event.position);
    final controller = widget.controller;
    if (!controller.isAttached || (widget.isSuspended?.call() ?? false)) {
      return;
    }
    final endSize = controller.size;
    final parentHeight = controller.sizeToPixels(1);
    // Ignore releases that only scrolled the list or tapped.
    if (parentHeight <= 0 || (startSize - endSize).abs() < 0.001) return;
    final target = daySheetReleaseTarget(
      startSize: startSize,
      endSize: endSize,
      downwardVelocity: tracker.getVelocity().pixelsPerSecond.dy / parentHeight,
      smallestStage: widget.smallestStage,
    );
    if (target == null) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The drag recognizer handles this same up event after this listener and
    // starts the sheet's own snap, so override it once that has run.
    scheduleMicrotask(() {
      if (!mounted || !controller.isAttached) return;
      if (reduceMotion) {
        controller.jumpTo(target);
      } else {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _reset() {
    _pointer = null;
    _startSize = null;
    _tracker = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _handleDown,
    onPointerMove: _handleMove,
    onPointerUp: _handleUp,
    onPointerCancel: (_) => _reset(),
    child: widget.child,
  );
}
