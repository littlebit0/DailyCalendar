import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/weather/weather_controller.dart';
import '../../../core/weather/weather_forecast.dart';
import '../../../core/weather/weather_strings.dart';
import '../../../core/weather/weather_widgets.dart';

class WeatherSettingsPage extends ConsumerWidget {
  const WeatherSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(weatherControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        final message = switch (controller.status) {
          WeatherStatus.chooseRegion => WeatherText.selectRegion,
          WeatherStatus.locationUnavailable => WeatherText.locationUnavailable,
          WeatherStatus.unavailable => WeatherText.unavailable,
          WeatherStatus.storageError => WeatherText.storageError,
          _ => null,
        };
        return Scaffold(
          backgroundColor: DailyUi.pageBackground(context),
          appBar: DailyNavigationBar(
            title: weatherText(context, WeatherText.title),
          ),
          body: DailyAdaptiveBody(
            child: ListView(
              children: [
                DailyGroupedSection(
                  children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey('weather-enabled'),
                      secondary: const DailySettingsIcon(
                        icon: Icons.cloud_outlined,
                      ),
                      title: Text(weatherText(context, WeatherText.enabled)),
                      value: settings.enabled,
                      onChanged: controller.saving
                          ? null
                          : (value) => unawaited(
                              controller.configure(
                                settings.copyWith(enabled: value),
                              ),
                            ),
                    ),
                    SwitchListTile.adaptive(
                      key: const ValueKey('weather-automatic'),
                      secondary: const DailySettingsIcon(
                        icon: Icons.my_location_outlined,
                      ),
                      title: Text(weatherText(context, WeatherText.automatic)),
                      value: settings.automaticLocation,
                      onChanged: !settings.enabled || controller.saving
                          ? null
                          : (value) => unawaited(
                              controller.configure(
                                settings.copyWith(automaticLocation: value),
                              ),
                            ),
                    ),
                    ListTile(
                      key: const ValueKey('weather-region'),
                      leading: const DailySettingsIcon(
                        icon: Icons.place_outlined,
                      ),
                      title: Text(weatherText(context, WeatherText.region)),
                      subtitle: _RegionName(controller: controller),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: controller.saving
                          ? null
                          : () async {
                              final region = await Navigator.of(context)
                                  .push<WeatherRegion>(
                                    MaterialPageRoute(
                                      builder: (_) => _WeatherRegionPicker(
                                        controller: controller,
                                      ),
                                    ),
                                  );
                              if (region != null) {
                                await controller.configure(
                                  controller.settings.copyWith(
                                    regionId: region.id,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  weatherText(context, WeatherText.forecastOnly),
                  style: TextStyle(color: DailyUi.secondaryText(context)),
                ),
                const SizedBox(height: 12),
                Text(
                  weatherText(context, WeatherText.privacy),
                  style: TextStyle(color: DailyUi.secondaryText(context)),
                ),
                if (settings.enabled) ...[
                  const SizedBox(height: 16),
                  if (controller.status == WeatherStatus.loading)
                    const LinearProgressIndicator(),
                  if (controller.usingManualFallback)
                    Text(weatherText(context, WeatherText.fallback)),
                  if (message != null) Text(weatherText(context, message)),
                  CalendarWeather(
                    date: weatherDate(koreaNow(controller.now())),
                    detailed: true,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed:
                          controller.status == WeatherStatus.loading ||
                              controller.saving
                          ? null
                          : () => unawaited(
                              controller.refresh(
                                force: true,
                                requestPermission: settings.automaticLocation,
                              ),
                            ),
                      icon: const Icon(Icons.refresh),
                      label: Text(weatherText(context, WeatherText.retry)),
                    ),
                  ),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.https('www.weather.go.kr', '/plus/rss.jsp'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(weatherText(context, WeatherText.source)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RegionName extends StatefulWidget {
  const _RegionName({required this.controller});
  final WeatherController controller;
  @override
  State<_RegionName> createState() => _RegionNameState();
}

class _RegionNameState extends State<_RegionName> {
  late final _regions = widget.controller.service.regions();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<WeatherRegion>>(
    future: _regions,
    builder: (context, snapshot) => Text(
      snapshot.data
              ?.where((r) => r.id == widget.controller.settings.regionId)
              .firstOrNull
              ?.name ??
          weatherText(context, WeatherText.selectRegion),
    ),
  );
}

class _WeatherRegionPicker extends StatefulWidget {
  const _WeatherRegionPicker({required this.controller});
  final WeatherController controller;
  @override
  State<_WeatherRegionPicker> createState() => _WeatherRegionPickerState();
}

class _WeatherRegionPickerState extends State<_WeatherRegionPicker> {
  late Future<List<WeatherRegion>> _regions = widget.controller.service
      .regions();
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: DailyNavigationBar(
      title: weatherText(context, WeatherText.selectRegion),
    ),
    backgroundColor: DailyUi.pageBackground(context),
    body: DailyAdaptiveBody(
      child: Column(
        children: [
          TextField(
            key: const ValueKey('weather-region-search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: weatherText(context, WeatherText.search),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<WeatherRegion>>(
              future: _regions,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(weatherText(context, WeatherText.retry)),
                      onPressed: () => setState(
                        () => _regions = widget.controller.service.regions(),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final terms = _query.split(RegExp(r'\s+'));
                final regions = snapshot.data!
                    .where((r) => terms.every(r.name.contains))
                    .toList();
                if (regions.isEmpty) {
                  return Center(
                    child: Text(weatherText(context, WeatherText.noResults)),
                  );
                }
                return ListView.builder(
                  itemCount: regions.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(regions[index].name),
                    trailing:
                        regions[index].id == widget.controller.settings.regionId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(regions[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
