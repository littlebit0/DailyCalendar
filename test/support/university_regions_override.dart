import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/university_regions.dart';
import 'package:daily/features/settings/presentation/academic_profile_page.dart';
import 'package:flutter_riverpod/misc.dart';

/// Loads the shipped region list from the repository instead of the bundle.
Override universityRegionsFromAsset() => universityRegionsProvider.overrideWith(
  (ref) async => UniversityRegions.fromJson(
    jsonDecode(
          File('assets/academic/university_regions.json').readAsStringSync(),
        )
        as Map<String, dynamic>,
  ),
);
