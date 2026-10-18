/// Runs [pass] one at a time and again whenever a request arrived during a pass.
///
/// A pass reads its pending work once when it starts, so a request that comes in
/// while it runs (a new widget click, another Siri change) must not be answered
/// with the already-running future alone: it would stay unprocessed until some
/// other trigger. Requests that arrive during one pass share a single rerun.
class CoalescingRunner {
  CoalescingRunner(this._pass);

  final Future<void> Function() _pass;
  Future<void>? _active;
  bool _again = false;

  /// Completes once a pass that started after this call has finished.
  Future<void> request() {
    final active = _active;
    if (active != null) {
      _again = true;
      return active;
    }
    return _active = _drain();
  }

  Future<void> _drain() async {
    try {
      do {
        _again = false;
        await _pass();
      } while (_again);
    } finally {
      _active = null;
    }
  }
}
