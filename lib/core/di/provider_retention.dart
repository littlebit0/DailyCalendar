import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps an auto-dispose provider alive for [duration] after its last listener
/// goes away, then lets Riverpod dispose it.
///
/// Page-to-page navigation and prefetching re-subscribe within moments, so a
/// short retention avoids a loading flash, while ranges nobody revisits are
/// released instead of accumulating for the life of the app.
void retainWhileRecentlyUsed(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() {
    timer?.cancel();
    timer = Timer(duration, link.close);
  });
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}
