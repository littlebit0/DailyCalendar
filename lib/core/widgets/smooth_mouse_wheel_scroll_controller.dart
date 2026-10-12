import 'dart:async';

import 'package:flutter/widgets.dart';

class SmoothMouseWheelScrollController extends ScrollController {
  SmoothMouseWheelScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothMouseWheelScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothMouseWheelScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothMouseWheelScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  double? _wheelTarget;
  var _animationRevision = 0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0 ||
        (MediaQuery.maybeOf(context.storageContext)?.disableAnimations ??
            false)) {
      super.pointerScroll(delta);
      return;
    }
    final baseTarget = _wheelTarget ?? pixels;
    final target = (baseTarget + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels) {
      if (_wheelTarget != null) {
        _animationRevision += 1;
        _wheelTarget = null;
        jumpTo(pixels);
      }
      return;
    }
    final revision = ++_animationRevision;
    _wheelTarget = target;
    unawaited(
      animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (revision == _animationRevision) {
          _wheelTarget = null;
        }
      }),
    );
  }
}
