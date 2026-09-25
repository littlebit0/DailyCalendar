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
          if (sync.state == LmsSyncState.fallback)
            Text(context.tr('학교에 연결하지 못해 마지막으로 확인한 데이터를 표시합니다.')),
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
}
