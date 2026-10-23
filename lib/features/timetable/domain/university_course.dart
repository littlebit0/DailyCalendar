import 'timetable.dart';
import 'timetable_term.dart';
import 'course_organization.dart';

enum CourseCategory {
  major('전공'),
  requiredMajor('전필'),
  certification('자격'),
  foundation('기초'),
  advancedMajor('전심'),
  electiveMajor('전선'),
  minorMajor('부선'),
  teaching('교직'),
  generalEducation('교양'),
  requiredGeneralEducation('교필'),
  electiveGeneralEducation('교선'),
  general('일반'),
  microDegree('MD'),
  unknown('미분류');

  const CourseCategory(this.label);
  final String label;
}

CourseCategory courseCategory(String classification) {
  final compact = classification.replaceAll(RegExp(r'\s+'), '');
  if (compact == '교필' ||
      compact == '교필영어' ||
      compact == '교양(소양필수)' ||
      compact.contains('교양필수') ||
      compact.startsWith('필수교양')) {
    return CourseCategory.requiredGeneralEducation;
  }
  if (compact == '교선' ||
      classification.trim().startsWith('교선 ') ||
      compact == '교선핵심' ||
      compact == '교선일반' ||
      compact.contains('교양선택') ||
      compact.contains('선택교양')) {
    return CourseCategory.electiveGeneralEducation;
  }
  return switch (classification.trim()) {
    '01 청람인성' ||
    '02 청람역량(창의융합)' ||
    '03 청람역량(안전보건환경)' ||
    '04 청람역량(다문화시민소통상담)' ||
    '05 청람탐구(인간과 삶)' ||
    '06 청람탐구(사회와 문화)' ||
    '07 청람탐구(자연과 과학)' ||
    '08 청람탐구(예술과 스포츠)' => CourseCategory.generalEducation,
    '21 교직이론' || '22 교직소양' || '23 교육실습' => CourseCategory.teaching,
    '30 전공심화(유아)' ||
    '31 교과교육기본' ||
    '32 교과교육선택' ||
    '33 교과내용기본' ||
    '34 교과내용선택' ||
    '35 전공기본(유아)' ||
    '37 전공기본(초등)' ||
    '38 전공선택(초등)' ||
    '39 전공심화(초등)' ||
    '61 전공기본(특수)' ||
    '62 전공선택(특수)' ||
    '63 전공기본(중등특수)' ||
    '64 교과교육' ||
    '81 융합' => CourseCategory.major,
    '52 군사학' => CourseCategory.general,
    '복필' ||
    '전필' ||
    '전공필수' ||
    '설계(건축)(필)' ||
    '건축적사고(건축)(필)' ||
    '기술(건축)(필)' ||
    '실무(건축)(필)' => CourseCategory.requiredMajor,
    '기초과목' ||
    '학문기초' ||
    '전공기초' ||
    '전공(기초)' ||
    '대학기초' ||
    '공학기초' ||
    '기필' ||
    '기선' ||
    '기전' ||
    '전기' ||
    '기초(자연)' => CourseCategory.foundation,
    '전심' || '1전심' || '전공심화' || '전공(심화)' => CourseCategory.advancedMajor,
    '복선' ||
    '전선' ||
    '전공선택' ||
    '복전선' ||
    '1전선' ||
    'SW선택' ||
    '융합선택' ||
    'SW융합선택' => CourseCategory.electiveMajor,
    '이중(부)전공' ||
    '이중(제2)' ||
    '전공과목' ||
    '전공' ||
    '융합전공' ||
    '공학전공' ||
    '전공공통' ||
    '연계전공' ||
    '핵심전공' ||
    '전공(핵심)' ||
    '핵심(화학)' ||
    'POSE-AI(AI)' ||
    'POSE-AI(English)' ||
    'POSE-AI(Open Source)' ||
    '자유전공' => CourseCategory.major,
    '교직' ||
    '교직과목' ||
    '교직전공' ||
    '교직과정' ||
    '교직필수' ||
    '1교직' => CourseCategory.teaching,
    '부선' => CourseCategory.minorMajor,
    '평교' || '문화예술교육사' => CourseCategory.certification,
    '확대교양: 국제화' ||
    '일반교양: 사회와역사' ||
    '개신기초교양: 정보문해' ||
    '개신기초교양: 의사소통' ||
    '균교' ||
    '확교' ||
    '효원핵심교양' ||
    '효원균형교양' ||
    '효원창의교양' ||
    '전문교양' ||
    '교양(소양)' ||
    '교양(균형)' ||
    '교양(기초)' ||
    '교양(소양필수)' ||
    '교양과목' ||
    '영역별교양' ||
    '공학인증교양' ||
    '교선' ||
    '선필교' ||
    '일교' ||
    '교필' ||
    '계교' ||
    '교양필수' ||
    '공통교양필수' ||
    '학문기초교양필수' ||
    '균형교양필수' ||
    '교양선택' ||
    '교양선택(4영역)' ||
    '교양선택(6영역)' ||
    '교양' ||
    '공통교양' ||
    '균형교양' ||
    '글로컬교양' ||
    '일반교양' ||
    '기초교양' ||
    '핵심교양' ||
    '자유교양' ||
    '필수교양' ||
    '선택교양' ||
    '세계시민역량' ||
    '자기주도역량' ||
    '의사소통역량' ||
    '문제해결역량' ||
    '전문지식역량' ||
    '자원·정보·기술활용역량' ||
    '인문/사회' ||
    '예술/융합' ||
    '자연/공학/SDGs' ||
    'SW/AI' ||
    'Language & Humanities' ||
    'Social & Regional Studies' ||
    'Arts & Sports' ||
    'Science & SDGs' ||
    'Mathematics & SW·AI' ||
    'Management' ||
    '사회봉사교과' ||
    '컨소시엄' => CourseCategory.generalEducation,
    '일선과목' ||
    '일선' ||
    '일반선택' ||
    '자유선택' ||
    '군사학' ||
    'ROTC' ||
    '군필' ||
    '자선' ||
    '군사' ||
    '군사학' => CourseCategory.general,
    '1MD' || '마이크로디그리(영어)' || 'MD전선' => CourseCategory.microDegree,
    _ => CourseCategory.unknown,
  };
}

class UniversityCourse {
  UniversityCourse.fromJson(Map<String, dynamic> json)
    : sourceId = json['sourceId'] as String,
      campus = json['campus'] as String,
      academicYear = json['academicYear'] as int,
      semester = json['semester'] as String,
      code = json['courseCode'] as String,
      title = json['courseName'] as String,
      titleAliases = List<String>.unmodifiable(
        json['courseNameAliases'] as List? ?? const [],
      ),
      section = json['section'] as String,
      professor = json['professor'] as String,
      sourceSchedule = json['sourceSchedule'] as String? ?? '',
      sourceClassroom = json['sourceClassroom'] as String? ?? '',
      scheduleStatus = json['scheduleStatus'] as String?,
      sourceClassification = json['classification'] as String? ?? '',
      sourceClassificationGroup = json['classificationGroup'] as String? ?? '',
      sourceRemarks = json['remarks'] as String? ?? '',
      period = json['period'] == null
          ? null
          : TimetablePeriod.fromJson(
              Map<String, dynamic>.from(json['period'] as Map),
            ),
      credits = (json['credits'] as num?)?.toDouble(),
      departmentCredits = Map<String, num>.from(
        json['departmentCredits'] as Map,
      ),
      departmentClassifications = Map<String, String>.unmodifiable(
        Map<String, String>.from(
          json['departmentClassifications'] as Map? ?? const {},
        ),
      ),
      departmentRemarks = Map<String, String>.unmodifiable(
        Map<String, String>.from(json['departmentRemarks'] as Map? ?? const {}),
      ),
      departments = List<String>.unmodifiable(json['departments'] as List),
      offeringOrganizations = List<CourseOrganization>.unmodifiable([
        for (final unit in json['offeringOrganizations'] as List? ?? const [])
          CourseOrganization.fromJson(Map<String, dynamic>.from(unit as Map)),
      ]),
      meetings = List<ClassMeeting>.unmodifiable([
        for (final (index, meeting) in (json['schedules'] as List).indexed)
          ClassMeeting.fromJson({
            ...Map<String, dynamic>.from(meeting as Map),
            'id': 'meeting-$index',
          }),
      ]),
      _publishedMeetingModes = _readPublishedMeetingModes(
        json['schedules'] as List,
      ) {
    if (sourceId.isEmpty ||
        title.isEmpty ||
        titleAliases.any((value) => value.trim().isEmpty) ||
        (departments.isEmpty &&
            sourceClassification.trim().isEmpty &&
            code.trim().isEmpty) ||
        (scheduleStatus != null &&
            scheduleStatus != 'scheduled' &&
            scheduleStatus != 'unscheduled' &&
            scheduleStatus != 'unrecognized') ||
        (meetings.isEmpty &&
            scheduleStatus != 'unscheduled' &&
            scheduleStatus != 'unrecognized') ||
        _publishedMeetingModes.keys.any(
          (index) => meetings[index].date == null,
        ) ||
        meetings.any(
          (m) =>
              !m.isValid ||
              (m.date != null &&
                  period != null &&
                  !period!.contains(m.teachingDate!)),
        )) {
      throw const FormatException('Invalid university course');
    }
  }
  final String sourceId, campus, semester, code, title, section, professor;

  /// Alternate names published for the same native offering, never joined into its title.
  final List<String> titleAliases;

  /// School-level source notes when no department was published.
  final String sourceRemarks;
  final String sourceSchedule;
  final String sourceClassroom;
  final String? scheduleStatus;

  /// Institution-wide offerings can publish a category without a department.
  final String sourceClassification;
  final String sourceClassificationGroup;
  final TimetablePeriod? period;
  bool get hasSchedulableMeetings => meetings.isNotEmpty;
  final int academicYear;
  final double? credits;
  final Map<String, num> departmentCredits;

  /// Exact classification text from the official row for each department.
  /// Cross-listed courses may be advanced in one department and elective in another.
  final Map<String, String> departmentClassifications;

  /// Original remarks for each published department row, including line breaks.
  /// Empty values mean the source row has no remarks, not unrestricted enrollment.
  final Map<String, String> departmentRemarks;
  final List<String> departments;
  final List<CourseOrganization> offeringOrganizations;

  bool matchesOrganization(CourseOrganization organization) =>
      offeringOrganizations.any((unit) => unit.key == organization.key);
  final List<ClassMeeting> meetings;
  final Map<int, LectureMode> _publishedMeetingModes;
  String get codeAndSection => code.isEmpty
      ? (section.isEmpty ? '' : '분반 $section')
      : (section.isEmpty ? code : '$code-$section');

  String remarkForDepartment(String department) =>
      departmentRemarks[department] ?? '';

  String get remarks {
    if (departmentRemarks.isEmpty) return sourceRemarks;
    final values = departmentRemarks.values.toSet();
    if (values.length == 1) return values.single;
    return departmentRemarks.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => '${entry.key}\n${entry.value}')
        .join('\n\n');
  }

  Iterable<String> _classificationsFor(String? department) {
    return departmentClassifications.isEmpty &&
            sourceClassification.trim().isNotEmpty
        ? [sourceClassification]
        : department == null
        ? departmentClassifications.values
        : [
            if (departmentClassifications[department] case final String code)
              code,
          ];
  }

  CourseCategory _categoryFor(String classification) {
    final university = sourceId.split(RegExp(r'[/\-]')).first;
    return switch ((university, classification)) {
      ('daegu', '공통' || '균형') => CourseCategory.generalEducation,
      ('daegu', '자유') => CourseCategory.general,
      ('jeju', 'JNU소양' || '글로벌자율전공') => CourseCategory.generalEducation,
      ('hanbat', '심선') => CourseCategory.advancedMajor,
      _ => courseCategory(classification),
    };
  }

  /// Only published classifications form filters. Unknown native labels remain
  /// literal instead of becoming an invented "unclassified" category.
  List<String> classificationLabelsFor([String? department]) =>
      _labelsFor(_classificationsFor(department));

  List<String> _labelsFor(Iterable<String> classifications) => classifications
      .map((raw) {
        final category = _categoryFor(raw);
        return category == CourseCategory.unknown ? raw.trim() : category.label;
      })
      .where((label) => RegExp(r'[A-Za-z0-9가-힣]').hasMatch(label))
      .toSet()
      .toList();

  Iterable<String> _organizationClassifications(CourseOrganization unit) {
    final classifications = <String>{};
    for (final owner in offeringOrganizations.where(
      (owner) => owner.key == unit.key,
    )) {
      if (departmentClassifications[owner.sourceLabel] case final String raw) {
        classifications.add(raw);
      }
    }
    // Native course-wide classification is valid only if no matching query
    // classification exists; never borrow another department's classification.
    if (classifications.isEmpty && sourceClassification.trim().isNotEmpty) {
      classifications.add(sourceClassification);
    }
    if (classifications.isEmpty &&
        departmentClassifications.values.toSet().length == 1) {
      classifications.addAll(departmentClassifications.values);
    }
    return classifications;
  }

  List<String> classificationLabelsForOrganization(CourseOrganization? unit) =>
      unit == null
      ? classificationLabelsFor()
      : _labelsFor(_organizationClassifications(unit));

  /// Department lookup lists major courses only. General education remains in
  /// whole search even if the department directly opens it.
  bool isMajorForOrganization(CourseOrganization unit) =>
      _organizationClassifications(unit).any(_isMajorClassification);

  bool isMajorForSourceDepartment(String department) =>
      _classificationsFor(department).any(_isMajorClassification);

  List<String> majorClassificationLabelsForOrganization(
    CourseOrganization unit,
  ) => _labelsFor(
    _organizationClassifications(unit).where(_isMajorClassification),
  );

  List<String> majorClassificationLabelsForSourceDepartment(
    String department,
  ) =>
      _labelsFor(_classificationsFor(department).where(_isMajorClassification));

  bool _isMajorClassification(String raw) {
    final school = sourceId.split(RegExp(r'[/\-]')).first;
    // Jeju's 2026-2 course guide lists the 글로벌자율전공 classification as
    // 교양교과목 (081111~081191), so its "전공" suffix is not a major.
    if (school == 'jeju' && raw.trim() == '글로벌자율전공') return false;
    // Official curriculum legends: UIC MR/ME/MB are majors, CC is common;
    // Baekseok groups below are its published major curriculum stages.
    final nativeMajor = switch ((school, raw.trim())) {
      ('yonsei', 'MR' || 'ME' || 'MB' || '학필' || '학선') => true,
      // KOREATECH graduation rules: faculty-common required/elective are
      // major categories 07/08. Kyonggi publishes the same native abbreviations
      // in its major timetable and minimum major-credit requirements.
      ('koreatech' || 'kyonggi', '학필' || '학선') => true,
      ('baekseok', '기초교과군' || '핵심교과군' || '심화교과군' || '응용교과군') => true,
      _ => false,
    };
    // A literal curriculum-stage label can have an official course-wide
    // major group. Use it only for that exact label, never to override a
    // different department's published general-education classification.
    final publishedMajorGroup =
        sourceClassificationGroup == '전공' &&
        raw.trim() == sourceClassification.trim() &&
        _categoryFor(raw) == CourseCategory.unknown;
    return nativeMajor ||
        publishedMajorGroup ||
        isMajorClassificationLabel(raw) ||
        const {
          CourseCategory.major,
          CourseCategory.requiredMajor,
          CourseCategory.advancedMajor,
          CourseCategory.electiveMajor,
          CourseCategory.minorMajor,
          CourseCategory.microDegree,
        }.contains(_categoryFor(raw));
  }

  static bool isMajorClassificationLabel(String label) {
    if (label.contains('교양') ||
        label.contains('교직') ||
        const ['교필', '교선', '교양', '교직', '일반', '자격'].contains(label)) {
      return false;
    }
    return const [
          '전공',
          '전필',
          '전선',
          '전심',
          '부선',
          'MD',
          '전기',
          '기전',
          '전핵',
        ].contains(label) ||
        label.contains('전공') ||
        RegExp(r'^(?:[1-9]\s*)?전(?:필|선|심|핵|기)(?:$|[\s(/-])').hasMatch(label);
  }

  List<CourseCategory> categoriesFor([String? department]) {
    final classifications = _classificationsFor(department);
    final categories = classifications.map(_categoryFor).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return categories.isEmpty ? [CourseCategory.unknown] : categories;
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        UniversityCourseSearchText(
          this,
        ).matches(normalized.split(RegExp(r'\s+')));
  }

  int queryRank(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    if (codeAndSection.toLowerCase() == normalized ||
        [
          title,
          ...titleAliases,
        ].any((value) => value.toLowerCase() == normalized)) {
      return 0;
    }
    if ([
          title,
          ...titleAliases,
        ].any((value) => value.toLowerCase().startsWith(normalized)) ||
        codeAndSection.toLowerCase().startsWith(normalized)) {
      return 1;
    }
    if ([
      title,
      ...titleAliases,
    ].any((value) => value.toLowerCase().contains(normalized))) {
      return 2;
    }
    return 3;
  }

  // The user's default applies where the school has not explicitly published
  // a delivery mode for an exact dated session.
  TimetableClass toTimetable({required String id, required LectureMode mode}) =>
      TimetableClass(
        id: id,
        title: title,
        academicYear: academicYear,
        semester: semester,
        professor: professor,
        note: remarks,
        meetings: meetings,
        defaultMode: mode,
        sourceType: 'universityDataset',
        sourceId: sourceId,
        period: period,
        overrides: {
          for (final entry in _publishedMeetingModes.entries)
            '${meetings[entry.key].id}/${meetings[entry.key].date}':
                entry.value,
        },
      );
}

Map<int, LectureMode> _readPublishedMeetingModes(List schedules) {
  final modes = <int, LectureMode>{};
  for (final (index, schedule) in schedules.indexed) {
    final raw = (schedule as Map)['deliveryMode'];
    if (raw == null) continue;
    // Untimed video windows cannot be represented as timed class meetings.
    final mode = switch (raw) {
      'inPerson' => LectureMode.inPerson,
      'liveOnline' => LectureMode.liveOnline,
      _ => throw const FormatException('Invalid published meeting mode'),
    };
    modes[index] = mode;
  }
  return Map.unmodifiable(modes);
}

String _hangulInitials(String value) {
  const initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
  return String.fromCharCodes(
    value.runes.map((rune) {
      if (rune >= 0xac00 && rune <= 0xd7a3) {
        return initials.codeUnitAt((rune - 0xac00) ~/ 588);
      }
      return rune;
    }),
  );
}

/// Reused by a catalog page; lifetime is bounded by its selected dataset.
class UniversityCourseSearchText {
  UniversityCourseSearchText(UniversityCourse course)
    : text =
          ('${course.title} ${course.titleAliases.join(' ')} ${course.codeAndSection} ${course.professor} '
                  '${course.sourceClassification} '
                  '${course.departmentClassifications.values.join(' ')} '
                  '${course.categoriesFor().map((c) => c.label).join(' ')} '
                  '${course.sourceClassroom} ${course.meetings.map((m) => m.classroom).join(' ')}')
              .toLowerCase() {
    initials = _hangulInitials(text);
  }
  final String text;
  late final String initials;
  bool matches(List<String> normalizedWords) => normalizedWords.every(
    (word) => text.contains(word) || initials.contains(word),
  );
}
