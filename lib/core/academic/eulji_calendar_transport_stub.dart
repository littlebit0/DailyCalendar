import 'package:http/http.dart' as http;

Future<http.Response> fetchEuljiCalendar(
  Uri uri, {
  Duration timeout = const Duration(seconds: 25),
}) => Future.error(
  UnsupportedError('Eulji native HTTP compatibility unavailable'),
);
