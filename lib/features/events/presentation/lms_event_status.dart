import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/lms/lms_models.dart';
import '../../../core/lms/lms_sync_service.dart';
import '../../../core/localization/app_localizations.dart';

class LmsEventStatus extends ConsumerWidget {
  const LmsEventStatus({super.key, required this.metadata});
  final LmsEventMetadata metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(lmsControllerProvider).sync;
    final type = switch (metadata.activityType) {
      'assignment' => '과제',
      'quiz' => '퀴즈',
      'lecture' => '강의',
      _ => '일정',
    };
    final last = sync.lastSuccess;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LMS · ${context.tr(type)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (metadata.submissionStatus != null)
            Text(
              context.tr(
                '학교 제출 상태: {status}',
                args: {'status': metadata.submissionStatus!},
              ),
            ),
          if (metadata.progressPercent != null)
            Text(
              context.tr(
                '학습 진도: {percent}%',
                args: {'percent': metadata.progressPercent!},
              ),
            ),
          if (metadata.learnedSeconds != null &&
              metadata.requiredLearningSeconds != null)
            Text(
              context.tr(
                '학습시간: {learned} / 출석 요구시간: {required}',
                args: {
                  'learned': _learningTime(context, metadata.learnedSeconds!),
                  'required': _learningTime(
                    context,
                    metadata.requiredLearningSeconds!,
                  ),
                },
              ),
            ),
          if (sync.state == LmsSyncState.needsLogin)
            Text(context.tr('학교에 다시 로그인해 주세요. 기존 일정은 마지막으로 확인한 상태로 유지됩니다.')),
          if (sync.state == LmsSyncState.fallback)
            Text(context.tr('학교에 연결하지 못해 마지막으로 확인한 데이터를 표시합니다.')),
          if (type == '강의' &&
              (metadata.learnedSeconds != null ||
                  metadata.progressPercent != null) &&
              sync.lastResult?.learningCoverageIncomplete == true)
            // The last sync kept the earlier learning values for what it could
            // not read, so the time below belongs to the whole sync, not to this item.
            Text(
              context.tr('일부 학습 정보를 이번에 확인하지 못해 위 학습 정보는 이전에 확인한 값일 수 있습니다.'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (last != null)
            Text(
              context.tr(
                '최근 확인: {time}',
                args: {
                  'time': DateFormat.yMd(
                    context.l10n.locale.toLanguageTag(),
                  ).add_Hm().format(last.toLocal()),
                },
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }

  String _learningTime(BuildContext context, int seconds) => context.tr(
    '{minutes}분 {seconds}초',
    args: {'minutes': seconds ~/ 60, 'seconds': seconds % 60},
  );
}
