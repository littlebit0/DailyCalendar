import 'timetable.dart';

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
  general('일반'),
  microDegree('MD'),
  unknown('미분류');

  const CourseCategory(this.label);
  final String label;
}

CourseCategory courseCategory(String classification) =>
    switch (classification) {
      '전필' ||
      '전공필수' ||
      '설계(건축)(필)' ||
      '건축적사고(건축)(필)' ||
      '기술(건축)(필)' ||
      '실무(건축)(필)' => CourseCategory.requiredMajor,
      '학문기초' ||
      '전공기초' ||
      '대학기초' ||
      '공학기초' ||
      '기초(자연)' => CourseCategory.foundation,
      '전심' || '1전심' => CourseCategory.advancedMajor,
      '전선' ||
      '전공선택' ||
      '1전선' ||
      'SW선택' ||
      '융합선택' ||
      'SW융합선택' => CourseCategory.electiveMajor,
      '핵심전공' ||
      '핵심(화학)' ||
      'POSE-AI(AI)' ||
      'POSE-AI(English)' ||
      'POSE-AI(Open Source)' ||
      '자유전공' => CourseCategory.major,
      '교직' || '1교직' => CourseCategory.teaching,
      '부선' => CourseCategory.minorMajor,
      '문화예술교육사' => CourseCategory.certification,
      '교선' ||
      '교필' ||
      '교양필수' ||
      '교양선택' ||
      '교양' ||
      '공통교양' ||
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
      '일선' || '일반선택' || '군사학' || '군사' => CourseCategory.general,
      '1MD' => CourseCategory.microDegree,
      _ => CourseCategory.unknown,
    };

class UniversityCourse {
  UniversityCourse.fromJson(Map<String, dynamic> json)
    : sourceId = json['sourceId'] as String,
      campus = json['campus'] as String,
      academicYear = json['academicYear'] as int,
      semester = json['semester'] as String,
      code = json['courseCode'] as String,
      title = json['courseName'] as String,
      section = json['section'] as String,
      professor = json['professor'] as String,
      sourceSchedule = json['sourceSchedule'] as String? ?? '',
      sourceClassroom = json['sourceClassroom'] as String? ?? '',
      scheduleStatus = json['scheduleStatus'] as String?,
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
      meetings = List<ClassMeeting>.unmodifiable([
        for (final (index, meeting) in (json['schedules'] as List).indexed)
          ClassMeeting.fromJson({
            ...Map<String, dynamic>.from(meeting as Map),
            'id': 'meeting-$index',
          }),
      ]) {
    if (sourceId.isEmpty ||
        title.isEmpty ||
        departments.isEmpty ||
        (scheduleStatus != null &&
            scheduleStatus != 'scheduled' &&
            scheduleStatus != 'unscheduled' &&
            scheduleStatus != 'unrecognized') ||
        (meetings.isEmpty &&
            scheduleStatus != 'unscheduled' &&
            scheduleStatus != 'unrecognized') ||
        meetings.any((m) => !m.isValid)) {
      throw const FormatException('Invalid university course');
    }
  }
  final String sourceId, campus, semester, code, title, section, professor;
  final String sourceSchedule;
  final String sourceClassroom;
  final String? scheduleStatus;
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
  final List<ClassMeeting> meetings;
  String get codeAndSection => '$code-$section';

  String remarkForDepartment(String department) =>
      departmentRemarks[department] ?? '';

  String get remarks {
    if (departmentRemarks.isEmpty) return '';
    final values = departmentRemarks.values.toSet();
    if (values.length == 1) return values.single;
    return departmentRemarks.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => '${entry.key}\n${entry.value}')
        .join('\n\n');
  }

  List<CourseCategory> categoriesFor([String? department]) {
    final classifications = department == null
        ? departmentClassifications.values
        : [
            if (departmentClassifications[department] case final String code)
              code,
          ];
    final categories = classifications.map(courseCategory).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return categories.isEmpty ? [CourseCategory.unknown] : categories;
  }

  bool matchesQuery(String query) {
    final text =
        '$title $codeAndSection $professor '
                '${departmentClassifications.values.join(' ')} '
                '${categoriesFor().map((c) => c.label).join(' ')} '
                '$sourceClassroom ${meetings.map((m) => m.classroom).join(' ')}'
            .toLowerCase();
    final initials = _hangulInitials(text);
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every((word) => text.contains(word) || initials.contains(word));
  }

  int queryRank(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    if (codeAndSection.toLowerCase() == normalized ||
        title.toLowerCase() == normalized) {
      return 0;
    }
    if (title.toLowerCase().startsWith(normalized) ||
        codeAndSection.toLowerCase().startsWith(normalized)) {
      return 1;
    }
    if (title.toLowerCase().contains(normalized)) return 2;
    return 3;
  }

  // Explicit user choice: the source dataset cannot supply a lecture mode.
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
      );
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
