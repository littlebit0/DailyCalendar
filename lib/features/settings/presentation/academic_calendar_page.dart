import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/academic/academic_calendar_service.dart';
import '../../../core/academic/academic_source.dart';
import '../../../core/academic/academic_store.dart';
import '../../../core/academic/academic_strings.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/theme/daily_ui.dart';
import '../../events/domain/event_category.dart';
import 'category_color_picker.dart';

class AcademicCalendarPage extends ConsumerStatefulWidget {
  const AcademicCalendarPage({super.key});
  @override
  ConsumerState<AcademicCalendarPage> createState() =>
      _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends ConsumerState<AcademicCalendarPage> {
  String? _sourceId;
  int _year = DateTime.now().year;
  AcademicPreview? _preview;
  final _selected = <String>{};
  final _draftColors = <String, int>{};
  bool _pickingColor = false;
  bool _localError = false;

  String text(AcademicText key, [Map<String, Object> args = const {}]) =>
      academicText(context, key, args);
  String date(DateTime value) =>
      DateFormat.yMd(Localizations.localeOf(context).toString()).format(value);

  Future<void> _pickColor(AcademicSource source, int current) async {
    if (_pickingColor) return;
    _pickingColor = true;
    final repository = ref.read(settingsRepositoryProvider);
    final generation = repository.academicStore.generation;
    try {
      final color = await showCategoryColorPicker(context, current);
      if (!mounted ||
          color == null ||
          generation != repository.academicStore.generation) {
        return;
      }
      final categoryExists = repository.load().categories.any(
        (c) => c.id == AcademicCalendarService.categoryId(source.id),
      );
      if (categoryExists) {
        await _perform(
          () => ref
              .read(academicCalendarServiceProvider)
              .setCategoryColor(source.id, color),
        );
      } else {
        setState(() => _draftColors[source.id] = color);
      }
    } finally {
      _pickingColor = false;
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _localError = false);
    try {
      await action();
    } on Object {
      if (mounted) setState(() => _localError = true);
    } finally {
      if (mounted) {
        ref.read(appSettingsProvider.notifier).state = ref
            .read(settingsRepositoryProvider)
            .load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(academicCalendarServiceProvider);
    final settings = ref.watch(appSettingsProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final source = service.sources.firstWhere(
          (s) => s.id == _sourceId,
          orElse: () => service.sources.first,
        );
        final color =
            settings.categories
                .where(
                  (c) => c.id == AcademicCalendarService.categoryId(source.id),
                )
                .firstOrNull
                ?.colorValue ??
            _draftColors[source.id] ??
            EventCategory.basic.colorValue;
        final result = service.result;
        return Scaffold(
          backgroundColor: DailyUi.pageBackground(context),
          appBar: DailyNavigationBar(title: text(AcademicText.title)),
          body: DailyAdaptiveBody(
            child: ListView(
              children: [
                if (service.busy) const LinearProgressIndicator(),
                DropdownButtonFormField<String>(
                  key: const ValueKey('academic-school'),
                  initialValue: source.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: text(AcademicText.school),
                  ),
                  items: [
                    for (final s in service.sources)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: service.busy
                      ? null
                      : (value) => setState(() {
                          _sourceId = value;
                          _preview = null;
                        }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: const ValueKey('academic-year'),
                  initialValue: _year,
                  decoration: InputDecoration(
                    labelText: text(AcademicText.year),
                  ),
                  items: [
                    for (
                      var year = DateTime.now().year - 1;
                      year <= DateTime.now().year + 1;
                      year++
                    )
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: service.busy
                      ? null
                      : (value) => setState(() {
                          _year = value!;
                          _preview = null;
                        }),
                ),
                const SizedBox(height: 12),
                Text(
                  text(AcademicText.yearRange, {'year': _year}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: ValueKey('academic-color-${source.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(text(AcademicText.categoryColor)),
                  trailing: IconButton(
                    tooltip: text(AcademicText.categoryColor),
                    onPressed: service.busy
                        ? null
                        : () => _pickColor(source, color),
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  onTap: service.busy ? null : () => _pickColor(source, color),
                ),
                const SizedBox(height: 8),
                DailyPrimaryButton(
                  key: const ValueKey('academic-preview'),
                  label: text(AcademicText.preview),
                  icon: Icons.school_outlined,
                  onPressed: service.busy
                      ? null
                      : () => _perform(() async {
                          final preview = await service.preview(source, _year);
                          if (!mounted) return;
                          setState(() {
                            _preview = preview;
                            _selected
                              ..clear()
                              ..addAll(
                                preview.events
                                    .where(
                                      (e) =>
                                          !(service
                                                  .subscriptions[source.id]
                                                  ?.excluded
                                                  .contains(e.sourceId) ??
                                              false),
                                    )
                                    .map((e) => e.sourceId),
                              );
                          });
                        }),
                ),
                TextButton.icon(
                  onPressed: () => _perform(() async {
                    if (!await launchUrl(
                      source.website,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('Cannot open source');
                    }
                  }),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(text(AcademicText.source)),
                ),
                if (service.unavailable || _localError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      text(AcademicText.unavailable),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (result != null) ...[
                  Text(
                    text(AcademicText.result, {
                      'added': result.added,
                      'updated': result.updated,
                    }),
                  ),
                  if (result.preserved > 0)
                    Text(
                      text(AcademicText.preserved, {'count': result.preserved}),
                    ),
                  if (result.failed > 0)
                    Text(text(AcademicText.failed, {'count': result.failed})),
                ],
                if (_preview case final preview?) ...[
                  const Divider(height: 32),
                  Text(
                    text(AcademicText.selection, {'count': _selected.length}),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    text(AcademicText.selectionNote),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(text(AcademicText.selectAll)),
                    value: _selected.length == preview.events.length,
                    onChanged: service.busy
                        ? null
                        : (value) => setState(() {
                            _selected.clear();
                            if (value == true) {
                              _selected.addAll(
                                preview.events.map((e) => e.sourceId),
                              );
                            }
                          }),
                  ),
                  for (final event in preview.events)
                    CheckboxListTile(
                      key: ValueKey('academic-event-${event.sourceId}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(event.title),
                      secondary: Icon(
                        Icons.circle,
                        size: 12,
                        color: Color(color),
                      ),
                      subtitle: Text(
                        '${date(event.start)} – ${date(DateTime(event.end.year, event.end.month, event.end.day - 1))}',
                      ),
                      value: _selected.contains(event.sourceId),
                      onChanged: service.busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _selected.add(event.sourceId);
                              } else {
                                _selected.remove(event.sourceId);
                              }
                            }),
                    ),
                ],
                if (service.subscriptions.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    text(AcademicText.connected),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final entry in service.subscriptions.entries) ...[
                    _subscriptionHeader(
                      service.sources.firstWhere((s) => s.id == entry.key),
                      entry.value,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(text(AcademicText.show)),
                      value: !settings.hiddenCategoryIds.contains(
                        AcademicCalendarService.categoryId(entry.key),
                      ),
                      onChanged: service.busy
                          ? null
                          : (show) => _perform(() async {
                              final repository = ref.read(
                                settingsRepositoryProvider,
                              );
                              final before = repository.load();
                              final hidden = before.hiddenCategoryIds.toSet();
                              final id = AcademicCalendarService.categoryId(
                                entry.key,
                              );
                              if (show) {
                                hidden.remove(id);
                              } else {
                                hidden.add(id);
                              }
                              await repository.save(
                                before.copyWith(
                                  hiddenCategoryIds: hidden.toList(),
                                ),
                                changedFrom: before,
                              );
                            }),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: service.busy
                              ? null
                              : () =>
                                    _perform(() => service.refresh(entry.key)),
                          icon: const Icon(Icons.refresh),
                          label: Text(text(AcademicText.refresh)),
                        ),
                        TextButton.icon(
                          onPressed: service.busy
                              ? null
                              : () => _perform(
                                  () => service.setEnabled(
                                    entry.key,
                                    !entry.value.enabled,
                                  ),
                                ),
                          icon: Icon(
                            entry.value.enabled ? Icons.link_off : Icons.link,
                          ),
                          label: Text(
                            text(
                              entry.value.enabled
                                  ? AcademicText.disconnect
                                  : AcademicText.reconnect,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: service.busy
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(text(AcademicText.remove)),
                                      content: Text(
                                        text(AcademicText.removeConfirm),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(
                                            text(AcademicText.cancel),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(
                                            text(AcademicText.remove),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && mounted) {
                                    await _perform(
                                      () => service.removeImported(entry.key),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(text(AcademicText.remove)),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
          bottomNavigationBar: _preview == null
              ? null
              : SafeArea(
                  top: false,
                  child: Align(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                        child: DailyPrimaryButton(
                          key: const ValueKey('academic-import'),
                          label: text(AcademicText.importSelected),
                          icon: Icons.download_outlined,
                          busy: service.busy,
                          onPressed: service.busy || _selected.isEmpty
                              ? null
                              : () => _perform(() async {
                                  await service.importSelection(
                                    _preview!,
                                    Set.of(_selected),
                                    colorValue:
                                        _draftColors[_preview!.source.id],
                                  );
                                  if (mounted) setState(() => _preview = null);
                                }),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _subscriptionHeader(
    AcademicSource source,
    AcademicSubscription subscription,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${source.name} · ${subscription.year}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          subscription.lastSuccess == null
              ? text(AcademicText.never)
              : text(AcademicText.lastUpdated, {
                  'date': date(subscription.lastSuccess!),
                }),
        ),
        if (subscription.enabled) Text(text(AcademicText.automatic)),
        if (subscription.failed)
          Text(
            text(AcademicText.unavailable),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
