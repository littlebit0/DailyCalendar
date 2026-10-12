import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Browser response location is retained so relative LMS links resolve safely.
class LmsHtmlPage {
  const LmsHtmlPage({required this.url, required this.html});

  final Uri url;
  final String html;
}

String normalizeLmsOwner(String owner) => owner.trim().toLowerCase();

/// School source data and explicit personal completion travel with the event.
/// Fetch timestamps and credentials belong only to the device connection.
class LmsEventMetadata {
  LmsEventMetadata({
    this.provider = 'coursemos',
    required this.schoolId,
    required String ownerId,
    required this.lmsUserId,
    required this.courseId,
    required this.courseTitle,
    required this.activityType,
    required this.activityId,
    required this.sourceUrl,
    DateTime? openAt,
    DateTime? dueAt,
    this.submissionStatus,
    this.progressPercent,
    this.sourceCompleted,
    this.manuallyCompleted = false,
    this.requiredLearningSeconds,
    this.learnedSeconds,
    this.attendanceStatus,
  }) : ownerId = normalizeLmsOwner(ownerId),
       openAt = openAt?.toUtc(),
       dueAt = dueAt?.toUtc() {
    if ([
      provider,
      schoolId,
      this.ownerId,
      lmsUserId,
      courseId,
      activityId,
    ].any((value) => value.trim().isEmpty)) {
      throw const FormatException('Missing LMS source identity');
    }
    if (!const {
      'assignment',
      'quiz',
      'lecture',
      'calendar',
    }.contains(activityType)) {
      throw const FormatException('Invalid LMS activity type');
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid LMS source URL');
    }
    if (requiredLearningSeconds != null && requiredLearningSeconds! <= 0 ||
        learnedSeconds != null && learnedSeconds! < 0) {
      throw const FormatException('Invalid LMS learning duration');
    }
    if (progressPercent != null &&
        (!progressPercent!.isFinite ||
            progressPercent! < 0 ||
            progressPercent! > 100)) {
      throw const FormatException('Invalid LMS progress');
    }
  }

  final String provider;
  final String schoolId;
  final String ownerId;
  final String lmsUserId;
  final String courseId;
  final String courseTitle;
  final String activityType;
  final String activityId;
  final String sourceUrl;
  final DateTime? openAt;
  final DateTime? dueAt;
  final String? submissionStatus;
  final double? progressPercent;
  final bool? sourceCompleted;

  /// Explicit user completion; independent of the school submission state.
  final bool manuallyCompleted;
  final int? requiredLearningSeconds;
  final int? learnedSeconds;
  final String? attendanceStatus;

  bool belongsToOwner(String? owner) =>
      owner != null && normalizeLmsOwner(owner) == ownerId;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'schoolId': schoolId,
    'ownerId': ownerId,
    'lmsUserId': lmsUserId,
    'courseId': courseId,
    'courseTitle': courseTitle,
    'activityType': activityType,
    'activityId': activityId,
    'sourceUrl': sourceUrl,
    'openAt': openAt?.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'submissionStatus': submissionStatus,
    'progressPercent': progressPercent,
    if (sourceCompleted != null) 'sourceCompleted': sourceCompleted,
    if (manuallyCompleted) 'manuallyCompleted': true,
    if (requiredLearningSeconds != null)
      'requiredLearningSeconds': requiredLearningSeconds,
    if (learnedSeconds != null) 'learnedSeconds': learnedSeconds,
    if (attendanceStatus != null) 'attendanceStatus': attendanceStatus,
  };

  factory LmsEventMetadata.fromJson(Map<String, Object?> json) {
    String string(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('Invalid LMS $key');
      return value;
    }

    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null) throw FormatException('Invalid LMS $key');
      return parsed.toUtc();
    }

    int? duration(String key) {
      final value = json[key];
      if (value != null && value is! int) {
        throw FormatException('Invalid LMS $key');
      }
      return value as int?;
    }

    final manual = json['manuallyCompleted'];
    if (manual != null && manual is! bool) {
      throw const FormatException('Invalid LMS manual completion');
    }
    final completed = json['sourceCompleted'];
    final attendance = json['attendanceStatus'];
    if (completed != null && completed is! bool ||
        attendance != null && attendance is! String) {
      throw const FormatException('Invalid LMS activity state');
    }
    final progress = json['progressPercent'];
    final status = json['submissionStatus'];
    if (progress != null && progress is! num ||
        status != null && status is! String) {
      throw const FormatException('Invalid LMS activity state');
    }
    return LmsEventMetadata(
      provider: string('provider'),
      schoolId: string('schoolId'),
      ownerId: string('ownerId'),
      lmsUserId: string('lmsUserId'),
      courseId: string('courseId'),
      courseTitle: string('courseTitle'),
      activityType: string('activityType'),
      activityId: string('activityId'),
      sourceUrl: string('sourceUrl'),
      openAt: date('openAt'),
      dueAt: date('dueAt'),
      submissionStatus: status as String?,
      progressPercent: (progress as num?)?.toDouble(),
      sourceCompleted: completed as bool?,
      manuallyCompleted: manual as bool? ?? false,
      requiredLearningSeconds: duration('requiredLearningSeconds'),
      learnedSeconds: duration('learnedSeconds'),
      attendanceStatus: attendance as String?,
    );
  }

  LmsEventMetadata copyWith({
    String? provider,
    String? schoolId,
    String? ownerId,
    String? lmsUserId,
    String? courseId,
    String? courseTitle,
    String? activityType,
    String? activityId,
    String? sourceUrl,
    DateTime? openAt,
    DateTime? dueAt,
    String? submissionStatus,
    double? progressPercent,
    bool? sourceCompleted,
    bool? manuallyCompleted,
    int? requiredLearningSeconds,
    int? learnedSeconds,
    String? attendanceStatus,
    bool clearSourceCompleted = false,
    bool clearLearningDurations = false,
    bool clearAttendanceStatus = false,
    bool clearOpenAt = false,
    bool clearDueAt = false,
    bool clearSubmissionStatus = false,
    bool clearProgressPercent = false,
  }) => LmsEventMetadata(
    provider: provider ?? this.provider,
    schoolId: schoolId ?? this.schoolId,
    ownerId: ownerId ?? this.ownerId,
    lmsUserId: lmsUserId ?? this.lmsUserId,
    courseId: courseId ?? this.courseId,
    courseTitle: courseTitle ?? this.courseTitle,
    activityType: activityType ?? this.activityType,
    activityId: activityId ?? this.activityId,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    openAt: clearOpenAt ? null : openAt ?? this.openAt,
    dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
    submissionStatus: clearSubmissionStatus
        ? null
        : submissionStatus ?? this.submissionStatus,
    sourceCompleted: clearSourceCompleted
        ? null
        : sourceCompleted ?? this.sourceCompleted,
    manuallyCompleted: manuallyCompleted ?? this.manuallyCompleted,
    requiredLearningSeconds: clearLearningDurations
        ? null
        : requiredLearningSeconds ?? this.requiredLearningSeconds,
    learnedSeconds: clearLearningDurations
        ? null
        : learnedSeconds ?? this.learnedSeconds,
    attendanceStatus: clearAttendanceStatus
        ? null
        : attendanceStatus ?? this.attendanceStatus,
    progressPercent: clearProgressPercent
        ? null
        : progressPercent ?? this.progressPercent,
  );

  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  @override
  bool operator ==(Object other) =>
      other is LmsEventMetadata && fingerprint == other.fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;
}
