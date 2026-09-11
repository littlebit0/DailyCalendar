import 'dart:convert';
import 'dart:io';

/// The .deb's per-user systemd timer delivers reminders even after Daily exits.
/// Calendar content never enters command-line arguments or system journal logs.
class LinuxNotificationScheduler {
  static const _helper = '/usr/lib/dailycalendar/reminders';

  Future<String> _run(List<String> arguments, {String? input}) async {
    final process = await Process.start(_helper, arguments);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final result = await process.exitCode;
    await errors;
    final text = await output;
    if (result != 0) {
      throw StateError('Linux notification service is unavailable ($result).');
    }
    return text;
  }

  Future<void> initialize() async => _run(['initialize']);

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduled,
    required bool repeatsDaily,
  }) async {
    await _run(
      ['schedule'],
      input: jsonEncode({
        'id': id,
        'title': title,
        'body': body,
        'scheduledAt': scheduled.millisecondsSinceEpoch ~/ 1000,
        'repeatsDaily': repeatsDaily,
      }),
    );
  }

  Future<void> cancel(int id) async => _run(['cancel', '$id']);

  Future<int> pendingCount() async => int.parse((await _run(['count'])).trim());
}
