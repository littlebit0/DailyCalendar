#!/usr/bin/env bash
set -uo pipefail
export FLUTTER_ROOT=/Users/kimhwi/Documents/Codex/2026-05-26/flutter-sdk
export PUB_CACHE=/Users/kimhwi/Documents/Codex/PubCache
bash tool/flutter.sh --no-version-check test --no-pub test/core/academic/expansion_a_academic_sources_test.dart test/core/academic/expansion_b_academic_sources_test.dart test/core/academic/expansion17_c_academic_sources_test.dart test/core/academic/kangnam_academic_source_test.dart test/core/academic/academic_profile_test.dart test/core/academic/university_directory_test.dart test/features/timetable/expansion17_catalog_test.dart test/features/timetable/university_catalog_loading_test.dart test/features/timetable/timetable_periods_test.dart test/features/timetable/timetable_period_provider_test.dart test/features/timetable/university_course_panel_test.dart test/features/timetable/timetable_baseline_display_test.dart > work/university-research/expansion17-20261011/combined-tests.log 2>&1
result=$?
echo "Combined tests exit: $result"
tail -c 2800 work/university-research/expansion17-20261011/combined-tests.log
exit "$result"
