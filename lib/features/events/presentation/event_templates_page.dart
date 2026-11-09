import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/update/update_required_view.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/event_template.dart';
import 'event_editor_dialog.dart';
import 'event_template_actions.dart';

/// Lists saved event templates: favorite, rename, edit, delete and reorder.
/// Changing or deleting a template never touches events created from it.
class EventTemplatesPage extends ConsumerWidget {
  const EventTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsRepositoryProvider).eventTemplates;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('일정 템플릿'))),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final templates = store.templates;
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    '저장된 템플릿이 없습니다. 일정 추가·수정 화면에서 \'템플릿으로 저장\'을 누르세요.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ReorderableListView.builder(
            itemCount: templates.length,
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final t in templates) t.id];
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              _run(context, ref, () => store.reorder(ids));
            },
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                key: ValueKey('event-template-${template.id}'),
                leading: IconButton(
                  tooltip: context.tr(template.favorite ? '즐겨찾기 해제' : '즐겨찾기'),
                  icon: Icon(
                    template.favorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                  onPressed: () => _run(
                    context,
                    ref,
                    () => store.save(
                      template.copyWith(favorite: !template.favorite),
                    ),
                  ),
                ),
                title: Text(template.name),
                subtitle: Text(
                  '${template.title} · ${_timeSummary(context, ref, template)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (blockedByRequiredUpdate(context, ref)) return;
                    switch (action) {
                      case 'rename':
                        _rename(context, ref, template);
                      case 'edit':
                        _edit(context, ref, template);
                      default:
                        _delete(context, ref, template);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(context.tr('이름 변경')),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.tr('내용 수정')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('삭제')),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _timeSummary(
    BuildContext context,
    WidgetRef ref,
    EventTemplate template,
  ) {
    final days = template.endDayOffset;
    if (template.allDay) {
      return days == 0
          ? context.tr('종일')
          : context.tr('종일 · {count}일', args: {'count': days + 1});
    }
    final localizations = MaterialLocalizations.of(context);
    final use24 = ref.read(appSettingsProvider).use24HourTime;
    String time(int minutes) => localizations.formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: use24,
    );
    final range = '${time(template.startMinutes)}–${time(template.endMinutes)}';
    return days == 0
        ? range
        : '$range ${context.tr('(+{count}일)', args: {'count': days})}';
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    EventTemplate template,
  ) async {
    final name = await showTemplateNameDialog(
      context,
      initialName: template.name,
    );
    if (name == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(settingsRepositoryProvider)
          .eventTemplates
          .save(template.copyWith(name: name)),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    EventTemplate template,
  ) async {
    final repository = ref.read(settingsRepositoryProvider);
    final categories = repository.load().categories;
    final category =
        categories.where((c) => c.id == template.categoryId).firstOrNull ??
        // A deleted category is shown as missing so the editor asks for a
        // new choice instead of silently switching to another one.
        EventCategory(
          id: template.categoryId,
          label: template.categoryId,
          colorValue: EventCategory.basic.colorValue,
        );
    final today = DateTime.now();
    final seed = template
        .draftOn(template.representableDayFrom(today), category)
        .toEvent(id: template.id, now: today, deviceId: '');
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        templateMode: true,
        initialDate: seed.startAt,
        event: seed,
        categories: categories,
        loadCategories: () => repository.load().categories,
        alarmService: ref.read(alarmServiceProvider),
        use24HourTime: ref.read(appSettingsProvider).use24HourTime,
      ),
    );
    if (draft == null || !context.mounted) return;
    await _run(context, ref, () async {
      final updated = EventTemplate.fromDraft(
        draft,
        id: template.id,
        name: template.name,
        favorite: template.favorite,
      );
      checkTemplateSpan(updated);
      await repository.eventTemplates.save(updated);
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EventTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('템플릿 삭제')),
        content: Text(
          context.tr(
            '\'{name}\' 템플릿을 삭제할까요? 이미 추가한 일정은 그대로 남습니다.',
            args: {'name': template.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(settingsRepositoryProvider)
          .eventTemplates
          .delete(template.id),
    );
  }

  /// Every template write; a required update stops it like event edits (#821).
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    if (blockedByRequiredUpdate(context, ref)) return;
    try {
      await action();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                error is EventTemplateUnavailable
                    ? error.message
                    : '템플릿을 저장하지 못했습니다. 다시 시도해 주세요.',
              ),
            ),
          ),
        );
      }
    }
  }
}
