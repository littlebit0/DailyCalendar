import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weather_controller.dart';
import 'weather_forecast.dart';
import 'weather_strings.dart';

class WeatherScope extends StatefulWidget {
  const WeatherScope({
    super.key,
    required this.controller,
    required this.child,
  });
  final WeatherController controller;
  final Widget child;
  static WeatherController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WeatherData>()?.notifier;
  @override
  State<WeatherScope> createState() => _WeatherScopeState();
}

class _WeatherScopeState extends State<WeatherScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(() {
      if (mounted) widget.controller.setForeground(true);
    });
  }

  @override
  void didUpdateWidget(covariant WeatherScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.setForeground(false);
      scheduleMicrotask(() {
        if (mounted) widget.controller.setForeground(true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission sheets temporarily make iOS inactive; do not cancel their work.
    if (state == AppLifecycleState.resumed) {
      widget.controller.setForeground(true);
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.controller.setForeground(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _WeatherData(notifier: widget.controller, child: widget.child);
}

class _WeatherData extends InheritedNotifier<WeatherController> {
  const _WeatherData({required super.notifier, required super.child});
}

IconData weatherIcon(WeatherCondition condition) => switch (condition) {
  WeatherCondition.clear => Icons.wb_sunny_outlined,
  WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
  WeatherCondition.cloudy => Icons.cloud_outlined,
  WeatherCondition.rain || WeatherCondition.sleet => Icons.water_drop_outlined,
  WeatherCondition.snow => Icons.ac_unit,
  WeatherCondition.shower => Icons.thunderstorm_outlined,
  WeatherCondition.unknown => Icons.cloud_off_outlined,
};

String conditionLabel(BuildContext context, WeatherCondition condition) =>
    weatherText(context, switch (condition) {
      WeatherCondition.clear => WeatherText.clear,
      WeatherCondition.partlyCloudy => WeatherText.partlyCloudy,
      WeatherCondition.cloudy => WeatherText.cloudy,
      WeatherCondition.rain => WeatherText.rain,
      WeatherCondition.snow => WeatherText.snow,
      WeatherCondition.sleet => WeatherText.sleet,
      WeatherCondition.shower => WeatherText.shower,
      WeatherCondition.unknown => WeatherText.unknown,
    });

class CalendarWeather extends StatelessWidget {
  const CalendarWeather({
    super.key,
    required this.date,
    this.detailed = false,
    this.small = false,
  });
  final DateTime date;
  final bool detailed;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final controller = WeatherScope.of(context);
    final weather = controller?.forDate(date);
    if (weather == null || controller == null) return const SizedBox.shrink();
    final label = conditionLabel(context, weather.condition);
    final summary = [
      label,
      if (weather.low != null)
        '${weatherText(context, WeatherText.low)} ${weather.low!.round()}°',
      if (weather.high != null)
        '${weatherText(context, WeatherText.high)} ${weather.high!.round()}°',
      if (weather.rainProbability != null)
        '${weatherText(context, WeatherText.rainProbability)} ${weather.rainProbability}%',
    ].join(' · ');
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final key = ValueKey('weather-${date.year}-${date.month}-${date.day}');
    if (detailed) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(weatherIcon(weather.condition), size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                  Text(
                    '${controller.region?.name ?? ''} · ${weatherText(context, WeatherText.source)}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                  if (controller.forecast != null)
                    Text(
                      '${weatherText(context, controller.status == WeatherStatus.unavailable ? WeatherText.cached : WeatherText.updated)} ${DateFormat.Md(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(controller.forecast!.fetchedAt.toLocal())}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: color),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final numeric = (weather.rainProbability ?? 0) >= 50
        ? '${weather.rainProbability}%'
        : weather.temperature != null
        ? '${weather.temperature!.round()}°'
        : '';
    return IgnorePointer(
      child: Semantics(
        label: '$summary, ${weatherText(context, WeatherText.source)}',
        child: ExcludeSemantics(
          child: SizedBox(
            key: key,
            height: small ? 14 : 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weatherIcon(weather.condition),
                    size: small ? 11 : 14,
                    color: color,
                  ),
                  if (numeric.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      numeric,
                      style: TextStyle(
                        fontSize: small ? 9 : 11,
                        height: 1,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
