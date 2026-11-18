import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'kma_weather_service.dart';
import 'weather_forecast.dart';
import 'weather_store.dart';

enum WeatherStatus {
  idle,
  loading,
  ready,
  chooseRegion,
  locationUnavailable,
  unavailable,
  storageError,
}

class WeatherController extends ChangeNotifier {
  WeatherController({
    required this.store,
    required this.service,
    required this.location,
    DateTime Function()? clock,
    Random? random,
  }) : now = clock ?? DateTime.now,
       _random = random ?? Random() {
    settings = store.load();
    store.addListener(_reset);
  }
  final WeatherStore store;
  final KmaWeatherService service;
  final WeatherLocation location;
  final DateTime Function() now;
  final Random _random;

  /// Wait after the first failed request; doubles with each further failure
  /// until it reaches [WeatherForecast.refreshInterval].
  static const retryInterval = Duration(minutes: 5);
  late WeatherSettings settings;
  WeatherForecast? forecast;
  WeatherRegion? region;
  WeatherStatus status = WeatherStatus.idle;
  bool usingManualFallback = false;
  bool saving = false;
  bool _disposed = false;
  bool _foreground = true;
  int _revision = 0;
  Future<void>? _pending;
  Timer? _timer;
  int _failures = 0;

  DailyWeather? forDate(DateTime date) =>
      settings.enabled ? forecast?.forDate(date, now()) : null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _invalidate() {
    _revision++;
    _pending = null;
    _failures = 0;
    _timer?.cancel();
    service.cancel();
  }

  void _reset() {
    _invalidate();
    settings = const WeatherSettings();
    region = null;
    forecast = null;
    status = WeatherStatus.idle;
    usingManualFallback = false;
    _notify();
  }

  Future<void> configure(WeatherSettings next) async {
    if (saving || _disposed) return;
    saving = true;
    final previous = settings;
    final previousForecast = forecast;
    final previousRegion = region;
    _invalidate();
    final revision = _revision;
    settings = next;
    forecast = null;
    region = null;
    status = WeatherStatus.idle;
    _notify();
    try {
      await store.save(next);
    } on Object {
      if (!_disposed && revision == _revision) {
        settings = previous;
        forecast = previousForecast;
        region = previousRegion;
        status = WeatherStatus.storageError;
        _schedule();
      }
      saving = false;
      _notify();
      return;
    }
    saving = false;
    _notify();
    if (_disposed || revision != _revision) return;
    await refresh(
      requestPermission:
          next.enabled && next.automaticLocation && !previous.automaticLocation,
    );
  }

  void setForeground(bool active) {
    _foreground = active;
    if (active) {
      unawaited(refresh());
    } else {
      _timer?.cancel();
    }
  }

  Future<void> refresh({bool requestPermission = false, bool force = false}) {
    if (_disposed || !settings.enabled || !_foreground) return Future.value();
    if (_pending != null) return _pending!;
    final revision = _revision;
    final operation = _refresh(
      revision,
      requestPermission: requestPermission,
      force: force,
    );
    _pending = operation;
    return operation.whenComplete(() {
      if (_disposed || revision != _revision) return;
      _pending = null;
      _schedule();
    });
  }

  bool _current(int revision) =>
      !_disposed && revision == _revision && settings.enabled;

  Future<void> _refresh(
    int revision, {
    required bool requestPermission,
    required bool force,
  }) async {
    status = WeatherStatus.loading;
    _notify();
    try {
      final regions = await service.regions();
      if (!_current(revision)) return;
      final manual = regions
          .where((r) => r.id == settings.regionId)
          .firstOrNull;
      var selected = manual;
      usingManualFallback = false;
      if (settings.automaticLocation) {
        try {
          final point = await location
              .current(requestPermission: requestPermission)
              .timeout(const Duration(seconds: 20));
          if (!_current(revision)) return;
          selected = point == null
              ? null
              : nearestWeatherRegion(regions, point.latitude, point.longitude);
        } on Object {
          selected = null;
        }
        if (!_current(revision)) return;
        if (selected == null) {
          selected = manual;
          usingManualFallback = true;
        }
      }
      if (selected == null) {
        forecast = null;
        region = null;
        status = settings.automaticLocation
            ? WeatherStatus.locationUnavailable
            : WeatherStatus.chooseRegion;
        _notify();
        return;
      }
      if (selected.gridKey != region?.gridKey) forecast = null;
      region = selected;
      if (forecast == null) {
        final cached = store.cached(selected.gridKey);
        if (cached != null) {
          try {
            forecast = WeatherForecast.parse(
              cached.xml,
              fetchedAt: cached.fetchedAt,
              region: selected,
            );
          } on Object {
            forecast = null;
          }
        }
      }
      _notify();
      if (!force && forecast?.freshAt(now()) == true) {
        _failures = 0;
        status = WeatherStatus.ready;
        _notify();
        return;
      }
      final xml = await service.fetch(selected);
      if (!_current(revision)) return;
      final fetchedAt = now();
      final result = WeatherForecast.parse(
        xml,
        fetchedAt: fetchedAt,
        region: selected,
      );
      if (!result.usableAt(fetchedAt)) {
        throw const FormatException('Stale KMA forecast');
      }
      forecast = result;
      _failures = 0;
      status = WeatherStatus.ready;
      try {
        await store.cache(selected.gridKey, xml, fetchedAt);
      } on Object {
        // A request reset or replaced while the cache was writing owns no state.
        if (_current(revision)) status = WeatherStatus.storageError;
      }
      if (_current(revision)) _notify();
    } on Object {
      if (!_current(revision)) return;
      if (forecast?.usableAt(now()) != true) forecast = null;
      _failures++;
      status = WeatherStatus.unavailable;
      _notify();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!settings.enabled || !_foreground) return;
    _timer = Timer(nextRefreshDelay(), () => unawaited(refresh()));
  }

  /// Time until the next automatic request.
  @visibleForTesting
  Duration nextRefreshDelay() {
    final kst = koreaNow(now());
    final midnight = weatherDate(kst).add(const Duration(days: 1));
    final untilMidnight = midnight.difference(kst);
    final regular = untilMidnight < WeatherForecast.refreshInterval
        ? untilMidnight
        : WeatherForecast.refreshInterval;
    if (_failures == 0) return regular;
    // Up to 20% extra, so apps that failed together (an outage, the shared
    // midnight refresh) do not all ask the weather server again at once.
    final retry =
        retryInterval *
        (1 << min(_failures - 1, 6)) *
        (1 + _random.nextDouble() / 5);
    return retry < regular ? retry : regular;
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    store.removeListener(_reset);
    super.dispose();
  }
}
