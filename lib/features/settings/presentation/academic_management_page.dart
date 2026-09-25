import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/academic/academic_profile.dart';
import '../../../core/academic/academic_strings.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../timetable/presentation/timetable_settings_page.dart';
import 'academic_calendar_page.dart';
import 'academic_profile_page.dart';
import 'lms_settings_page.dart';

class AcademicManagementPage extends ConsumerWidget {
  const AcademicManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appSettingsProvider).academicProfile;
    final androidTablet =
        Theme.of(context).platform == TargetPlatform.android &&
        dailyWindowClassFor(MediaQuery.sizeOf(context)) !=
            DailyWindowClass.compact;
    return Scaffold(
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(title: context.tr('학사 관리')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              DailyUi.isDesktop || androidTablet ? 24 : 16,
              10,
              DailyUi.isDesktop || androidTablet ? 24 : 16,
              28,
            ),
            children: [
              Material(
                color: DailyUi.groupedSurface(context),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: DailyUi.separator(context).withValues(alpha: 0.78),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AcademicDestination(
                        key: const ValueKey('academic-profile-settings'),
                        icon: Icons.school_outlined,
                        title: context.tr('학사 정보'),
                        subtitle: _AcademicProfileSummary(profile: profile),
                        page: const AcademicProfilePage(),
                      ),
                      const Divider(height: 1),
                      _AcademicDestination(
                        key: const ValueKey('academic-lms-connection'),
                        icon: Icons.link_outlined,
                        title: context.tr('학교 LMS 연결'),
                        page: const LmsSettingsPage(),
                      ),
                      const Divider(height: 1),
                      _AcademicDestination(
                        key: const ValueKey('academic-calendar-settings'),
                        icon: Icons.event_note_outlined,
                        title: academicText(context, AcademicText.title),
                        page: const AcademicCalendarPage(),
                      ),
                      const Divider(height: 1),
                      _AcademicDestination(
                        key: const ValueKey('timetable-settings-navigation'),
                        icon: Icons.calendar_view_week_outlined,
                        title: context.tr('시간표 설정'),
                        page: const TimetableSettingsPage(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicDestination extends StatelessWidget {
  const _AcademicDestination({
    super.key,
    required this.icon,
    required this.title,
    required this.page,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ExcludeSemantics(
      child: DailySettingsIcon(icon: icon, color: DailyUi.primary),
    ),
    title: Text(title),
    subtitle: subtitle,
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(
      context,
    ).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => page)),
  );
}

class _AcademicProfileSummary extends ConsumerWidget {
  const _AcademicProfileSummary({this.profile});
  final AcademicProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = profile;
    if (value == null) return Text(context.tr('대학교 선택'));
    final directory = ref.watch(universityDirectoryProvider).asData?.value;
    final institution =
        directory?.institutionById(value.universityId) ??
        directory?.institutionForCampus(value.selectedCampusId);
    final campuses = institution?.campusSelectionRequired == true
        ? directory?.byId(value.selectedCampusId)?.campus ?? value.campus
        : institution?.campusSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(institution?.name ?? value.displayName),
        if (campuses != null && campuses.isNotEmpty)
          Text(
            campuses,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
