import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../settings/presentation/academic_profile_page.dart';
import '../data/timetable_store.dart';
import '../domain/timetable_term.dart';
import 'timetable_term_picker.dart';

/// Term management shares the existing Drive-backed store and term dialogs.
/// Class editing and temporary weekly view controls remain on TimetablePage.
class TimetableSettingsPage extends ConsumerWidget {
  const TimetableSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(timetableStoreProvider);
    Future<TimetablePeriod?> suggestPeriod(int year, String semester) async {
      final university =
          ref.read(appSettingsProvider).academicProfile?.timetableUniversity ??
          'smu';
      final defaults = await ref.read(timetablePeriodDefaultsProvider.future);
      return defaults.periodFor(year, semester, university: university);
    }

    return Scaffold(
      key: const ValueKey('timetable-settings-page'),
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(title: context.tr('시간표 설정')),
      body: AcademicFeatureGate(
        child: DailyAdaptiveBody(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final readable = store.loadError == null;
              return ListView(
                key: const ValueKey('timetable-settings-list'),
                children: [
                  if (!readable) ...[
                    Text(context.tr('시간표 데이터를 읽지 못했습니다. 기존 데이터는 보존됩니다.')),
                    const SizedBox(height: 16),
                  ],
                  DailyGroupedSection(
                    children: [
                      DailySettingsRow(
                        key: const ValueKey('timetable-settings-term'),
                        title: context.tr('시간표 선택'),
                        subtitle: timetableTermLabel(
                          context,
                          store.activeYear,
                          store.activeSemester,
                        ),
                        leading: const DailySettingsIcon(
                          icon: Icons.calendar_view_week_outlined,
                        ),
                        enabled: readable,
                        onTap: () => showTimetablePicker(
                          context,
                          store,
                          suggestPeriod: suggestPeriod,
                        ),
                      ),
                      DailySettingsRow(
                        key: const ValueKey('timetable-settings-name'),
                        title: context.tr('시간표 이름 변경'),
                        subtitle: store.activeName ?? context.tr('내 시간표'),
                        leading: const DailySettingsIcon(
                          icon: Icons.edit_outlined,
                        ),
                        enabled: readable,
                        onTap: () => _rename(context, store),
                      ),
                      DailySettingsRow(
                        key: const ValueKey('timetable-settings-period'),
                        title: context.tr('학기 기간 수정'),
                        subtitle: store.activePeriod == null
                            ? context.tr('학기 기간 설정 필요')
                            : timetablePeriodLabel(
                                context,
                                store.activePeriod!,
                              ),
                        leading: const DailySettingsIcon(
                          icon: Icons.date_range_outlined,
                        ),
                        enabled: readable,
                        onTap: () => showTimetablePeriodEditor(
                          context,
                          store,
                          store.activeYear,
                          store.activeSemester,
                          suggestPeriod: suggestPeriod,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('기간을 설정하면 주·일간 스케줄에 수업이 표시됩니다.'),
                    style: TextStyle(color: DailyUi.secondaryText(context)),
                  ),
                  const SizedBox(height: 24),
                  DailyGroupedSection(
                    children: [
                      DailySettingsRow(
                        key: const ValueKey('timetable-settings-reset'),
                        title: context.tr('시간표 전체 초기화'),
                        subtitle: context.tr(
                          '수업 {count}개',
                          args: {'count': store.activeClasses.length},
                        ),
                        leading: const DailySettingsIcon(
                          icon: Icons.delete_outline,
                          color: DailyUi.destructive,
                        ),
                        enabled: readable && store.activeClasses.isNotEmpty,
                        destructive: true,
                        onTap: () => _reset(context, store),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      store.hasPendingSync
                          ? '시간표 Google Drive 동기화 대기 중'
                          : '시간표는 Google Drive로 동기화됩니다.',
                    ),
                    style: TextStyle(color: DailyUi.secondaryText(context)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, TimetableStore store) async {
    final year = store.activeYear;
    final semester = store.activeSemester;
    var name = store.activeName ?? context.tr('내 시간표');
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('시간표 이름 변경')),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('timetable-name-input'),
            initialValue: name,
            onSaved: (value) => name = value!.trim(),
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(labelText: context.tr('시간표 이름')),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('필수 항목입니다.')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.pop(context, name);
              }
            },
            child: Text(context.tr('저장')),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await _save(context, () => store.renameTerm(year, semester, result));
    }
  }

  Future<void> _reset(BuildContext context, TimetableStore store) async {
    final year = store.activeYear;
    final semester = store.activeSemester;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('시간표 전체 초기화')),
        content: Text(context.tr('현재 학기의 모든 수업과 회차 변경을 삭제할까요?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _save(context, () => store.clearTerm(year, semester));
    }
  }
}

Future<void> _save(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('시간표를 저장하지 못했습니다. 다시 시도해 주세요.'))),
      );
    }
  }
}
