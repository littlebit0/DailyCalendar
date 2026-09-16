import 'dart:io';
import 'package:daily/core/academic/academic_source.dart';

Future<void> main(List<String> args) async {
  final source = SangmyungAcademicSource();
  try {
    final year = args.isEmpty ? DateTime.now().year : int.parse(args.single);
    final events = await source.fetch(year);
    stdout.writeln('${source.name} $year: ${events.length} official events');
    stdout.writeln(
      'Unique IDs: ${events.map((event) => event.dailyId(source.id)).toSet().length}',
    );
    stdout.writeln(
      'All periods valid: ${events.every((event) => event.end.isAfter(event.start))}',
    );
  } finally {
    source.close();
  }
}
