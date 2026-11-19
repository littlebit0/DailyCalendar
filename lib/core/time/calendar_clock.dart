import 'dart:async';

import 'package:flutter/widgets.dart';

typedef CalendarNow = DateTime Function();

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Time left until the device's next local midnight.
///
/// Building the next day from date fields keeps 23h/25h daylight-saving days
/// correct, unlike adding a fixed 24 hours.
Duration durationUntilNextLocalDay(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

/// Time left until the next wall-clock minute.
///
/// Subtracts the elapsed seconds instead of building `minute + 1`, which would
/// land an hour late inside the repeated hour when daylight saving ends.
Duration durationUntilNextMinute(DateTime now) =>
    const Duration(minutes: 1) -
    Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );

bool _stopsTimers(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

/// Publishes the device's local "today" and rebuilds dependents when it
/// changes: at local midnight and when the app returns to the foreground
/// (which also picks up time zone or clock changes made in system settings).
///
/// The midnight timer stops while the app is in the background.
class CalendarClockScope extends StatefulWidget {
  const CalendarClockScope({
    super.key,
    this.now = DateTime.now,
    required this.child,
  });

  /// Injectable for tests; production uses the device clock.
  final CalendarNow now;
  final Widget child;

  @override
  State<CalendarClockScope> createState() => _CalendarClockScopeState();
}

class _CalendarClockScopeState extends State<CalendarClockScope>
    with WidgetsBindingObserver {
  late DateTime _today;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = _dateOnly(widget.now());
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(covariant CalendarClockScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    } else if (_stopsTimers(state)) {
      _midnightTimer?.cancel();
      _midnightTimer = null;
    }
  }

  void _refresh() {
    if (!mounted) return;
    final today = _dateOnly(widget.now());
    if (today != _today) {
      setState(() => _today = today);
    }
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    // Recomputed from the clock on every fire, so an early or late timer only
    // reschedules instead of skipping or repeating a day.
    _midnightTimer = Timer(durationUntilNextLocalDay(widget.now()), _refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CalendarClockData(today: _today, now: widget.now, child: widget.child);
}

class _CalendarClockData extends InheritedWidget {
  const _CalendarClockData({
    required this.today,
    required this.now,
    required super.child,
  });

  final DateTime today;
  final CalendarNow now;

  @override
  bool updateShouldNotify(_CalendarClockData oldWidget) =>
      today != oldWidget.today || now != oldWidget.now;
}

abstract final class CalendarClock {
  /// Local date of today; dependents rebuild when the date changes.
  static DateTime todayOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CalendarClockData>()?.today ??
      _dateOnly(DateTime.now());

  /// Current time from the scope's clock (device clock without a scope).
  static DateTime nowOf(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<_CalendarClockData>()?.now ??
      DateTime.now)();
}

/// Rebuilds [builder] at each wall-clock minute, for the timeline's current
/// time line. Only mounted while today is on screen; stops in the background.
class CalendarMinuteTicker extends StatefulWidget {
  const CalendarMinuteTicker({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<CalendarMinuteTicker> createState() => _CalendarMinuteTickerState();
}

class _CalendarMinuteTickerState extends State<CalendarMinuteTicker>
    with WidgetsBindingObserver {
  Timer? _timer;
  var _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      setState(() {});
    } else if (_stopsTimers(state)) {
      _foreground = false;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = CalendarClock.nowOf(context);
    _timer?.cancel();
    _timer = _foreground ? Timer(durationUntilNextMinute(now), _tick) : null;
    return widget.builder(context, now);
  }
}
