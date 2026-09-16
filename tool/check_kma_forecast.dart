import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:daily/core/weather/weather_forecast.dart';

// Read-only service check using a public district, never the device's location.
Future<void> main(List<String> arguments) async {
  final id = arguments.firstOrNull ?? '1100000000';
  final data =
      jsonDecode(await File('assets/weather/kma_regions.json').readAsString())
          as List;
  final region = data
      .map((r) => WeatherRegion.fromJson(Map<String, dynamic>.from(r as Map)))
      .firstWhere((r) => r.id == id);
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.https('www.kma.go.kr', '/wid/queryDFS.jsp', {
            'gridx': '${region.x}',
            'gridy': '${region.y}',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('KMA HTTP ${response.statusCode}');
    }
    final now = DateTime.now();
    final forecast = WeatherForecast.parse(
      utf8.decode(response.bodyBytes),
      fetchedAt: now,
      region: region,
    );
    if (!forecast.usableAt(now)) {
      throw const FormatException('KMA returned expired forecast');
    }
    stdout.writeln(
      'region=${region.id} grid=${region.gridKey} issued=${forecast.issuedAt.toIso8601String()} periods=${forecast.periods.length}',
    );
    for (var day = 0; day < 6; day++) {
      final date = weatherDate(koreaNow(now)).add(Duration(days: day));
      final summary = forecast.forDate(date, now);
      if (summary != null) {
        stdout.writeln(
          '${date.toIso8601String().substring(0, 10)} ${summary.condition.name} low=${summary.low} high=${summary.high} pop=${summary.rainProbability}',
        );
      }
    }
  } finally {
    client.close();
  }
}
