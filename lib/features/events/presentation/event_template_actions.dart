import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/alarms/alarm_service.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/update/update_required_view.dart';
import '../domain/event_draft.dart';
import '../domain/event_template.dart';
import 'event_editor_dialog.dart';

/// Builds the event for [date] from [template] and saves it through the normal
/// event command path (notifications, widgets and Drive follow it as usual).
/// Throws [EventTemplateUnavailable] instead of saving a different event than
/// the template describes.
Future<void> createEventFromTemplate(
  WidgetRef ref,
  EventTemplate template,
  DateTime date,
) async {
  if (updateRequired(ref)) {
    throw const EventTemplateUnavailable('앱 업데이트가 필요해 일정을 추가할 수 없습니다.');
  }
  final category = ref
      .read(settingsRepositoryProvider)
      .load()
      .categories
      .where((category) => category.id == template.categoryId)
      .firstOrNull;
  if (category == null) {
    throw const EventTemplateUnavailable(
      '템플릿의 분류가 삭제되었습니다. 템플릿을 수정한 뒤 다시 시도해 주세요.',
    );
  }
  if (template.alarmEnabled) {
    final alarms = ref.read(alarmServiceProvider);
    var state = await alarms.authorizationState();
    if (state == AlarmAuthorizationState.notDetermined) {
      state = await alarms.requestAuthorization();
    }
    if (state != AlarmAuthorizationState.authorized) {
      throw const EventTemplateUnavailable(
        '일정 알람을 사용할 수 없어 바로 추가하지 않았습니다. 알람 권한을 확인하거나 일정을 직접 추가해 주세요.',
      );
    }
  }
  final draft = template.validDraftOn(date, category);
  if (draft == null) {
    throw const EventTemplateUnavailable(
      '이 날짜에는 템플릿 시간이 존재하지 않아 바로 추가하지 않았습니다. 일정을 직접 추가해 주세요.',
    );
  }
  await ref.read(eventCommandServiceProvider).create(draft);
}

/// Asks for a template name and stores [draft] as a new template.
Future<void> saveDraftAsTemplate(
  BuildContext context,
  WidgetRef ref,
  EventDraft draft,
) async {
  final name = await showTemplateNameDialog(context, initialName: draft.title);
  if (name == null) return;
  await ref
      .read(settingsRepositoryProvider)
      .eventTemplates
      .save(EventTemplate.fromDraft(draft, id: const Uuid().v4(), name: name));
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.tr('템플릿을 저장했습니다.'))));
  }
}

Future<String?> showTemplateNameDialog(
  BuildContext context, {
  required String initialName,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TemplateNameDialog(initialName: initialName),
);

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.initialName});
  final String initialName;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('템플릿 이름')),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: context.tr('예: 운동')),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('취소')),
      ),
      FilledButton(onPressed: _submit, child: Text(context.tr('저장'))),
    ],
  );
}

/// Template options for the create-event editor. Quick add uses the start
/// date the editor currently shows.
({
  List<EventTemplate> templates,
  Future<void> Function(EventTemplate, DateTime) onQuickAdd,
  Future<void> Function(EventDraft) onSaveTemplate,
})
eventTemplateEditorOptions(BuildContext context, WidgetRef ref) {
  return (
    templates: ref.read(settingsRepositoryProvider).eventTemplates.templates,
    onQuickAdd: (template, date) =>
        createEventFromTemplate(ref, template, date),
    onSaveTemplate: (draft) => saveDraftAsTemplate(context, ref, draft),
  );
}
