import 'package:xml/xml.dart';

enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  rain,
  snow,
  sleet,
  shower,
  unknown,
}

WeatherCondition kmaCondition(int? sky, int? precipitation) =>
    switch (precipitation) {
      1 || 5 => WeatherCondition.rain,
      2 || 6 => WeatherCondition.sleet,
      3 || 7 => WeatherCondition.snow,
      4 => WeatherCondition.shower,
      0 => switch (sky) {
        1 => WeatherCondition.clear,
        2 || 3 => WeatherCondition.partlyCloudy,
        4 => WeatherCondition.cloudy,
        _ => WeatherCondition.unknown,
      },
      _ => WeatherCondition.unknown,
    };

DateTime koreaNow(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9));
DateTime weatherDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class WeatherRegion {
  const WeatherRegion({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final String name;
  final int x;
  final int y;
  final double latitude;
  final double longitude;
  String get gridKey => '$x,$y';

  factory WeatherRegion.fromJson(Map<String, dynamic> json) => WeatherRegion(
    id: json['id'] as String,
    name: json['name'] as String,
    x: json['x'] as int,
    y: json['y'] as int,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

class WeatherPeriod {
  const WeatherPeriod({
    required this.date,
    required this.endsAt,
    required this.condition,
    this.temperature,
    this.low,
    this.high,
    this.rainProbability,
  });
  final DateTime date;
  final DateTime endsAt;
  final WeatherCondition condition;
  final double? temperature;
  final double? low;
  final double? high;
  final int? rainProbability;
}

class DailyWeather {
  const DailyWeather({
    required this.condition,
    this.temperature,
    this.low,
    this.high,
    this.rainProbability,
  });
  final WeatherCondition condition;
  final double? temperature;
  final double? low;
  final double? high;
  final int? rainProbability;
}

class WeatherForecast {
  const WeatherForecast({
    required this.issuedAt,
    required this.fetchedAt,
    required this.periods,
  });
  final DateTime issuedAt;
  final DateTime fetchedAt;
  final List<WeatherPeriod> periods;
  static const maximumAge = Duration(hours: 12);
  static const refreshInterval = Duration(hours: 3);

  bool usableAt(DateTime now) =>
      !issuedAt.isAfter(now.toUtc().add(const Duration(minutes: 10))) &&
      now.toUtc().difference(issuedAt) <= maximumAge;
  bool freshAt(DateTime now) =>
      usableAt(now) && now.toUtc().difference(fetchedAt) < refreshInterval;

  DailyWeather? forDate(DateTime date, DateTime now) {
    if (!usableAt(now) ||
        weatherDate(date).isBefore(weatherDate(koreaNow(now)))) {
      return null;
    }
    final items = periods
        .where(
          (p) => p.date == weatherDate(date) && p.endsAt.isAfter(now.toUtc()),
        )
        .toList();
    if (items.isEmpty) return null;
    final known = items
        .where((p) => p.condition != WeatherCondition.unknown)
        .toList();
    known.sort((a, b) => b.condition.index.compareTo(a.condition.index));
    final lows = items.map((p) => p.low).whereType<double>().toList();
    final highs = items.map((p) => p.high).whereType<double>().toList();
    final rain = items.map((p) => p.rainProbability).whereType<int>().toList()
      ..sort();
    return DailyWeather(
      condition: known.isEmpty
          ? WeatherCondition.unknown
          : known.first.condition,
      temperature: items
          .map((p) => p.temperature)
          .whereType<double>()
          .firstOrNull,
      low: lows.firstOrNull,
      high: highs.firstOrNull,
      rainProbability: rain.lastOrNull,
    );
  }

  factory WeatherForecast.parse(
    String source, {
    required DateTime fetchedAt,
    required WeatherRegion region,
  }) {
    final document = XmlDocument.parse(source);
    final header = document.findAllElements('header').first;
    String? value(XmlElement element, String tag) =>
        element.getElement(tag)?.innerText.trim();
    final rawTime = value(header, 'tm') ?? '';
    if (!RegExp(r'^\d{12}$').hasMatch(rawTime) ||
        int.tryParse(value(header, 'x') ?? '') != region.x ||
        int.tryParse(value(header, 'y') ?? '') != region.y) {
      throw const FormatException('Invalid KMA forecast header');
    }
    final base = DateTime.utc(
      int.parse(rawTime.substring(0, 4)),
      int.parse(rawTime.substring(4, 6)),
      int.parse(rawTime.substring(6, 8)),
    );
    final hour = int.parse(rawTime.substring(8, 10));
    final minute = int.parse(rawTime.substring(10, 12));
    if (base.month != int.parse(rawTime.substring(4, 6)) ||
        base.day != int.parse(rawTime.substring(6, 8)) ||
        hour > 23 ||
        minute > 59) {
      throw const FormatException('Invalid KMA issue date');
    }
    final issuedAt = base.add(Duration(hours: hour - 9, minutes: minute));
    double? temperature(XmlElement item, String tag) {
      final n = double.tryParse(value(item, tag) ?? '');
      return n != null && n.isFinite && n >= -90 && n <= 60 ? n : null;
    }

    final periods = <WeatherPeriod>[];
    for (final item in document.findAllElements('data')) {
      final day = int.tryParse(value(item, 'day') ?? '');
      final hour = int.tryParse(value(item, 'hour') ?? '');
      if (day == null ||
          day < 0 ||
          day > 5 ||
          hour == null ||
          hour < 0 ||
          hour > 24) {
        continue;
      }
      final pop = int.tryParse(value(item, 'pop') ?? '');
      final date = base.add(Duration(days: day));
      // KMA's hour 24 ends at next midnight, but describes this forecast day.
      periods.add(
        WeatherPeriod(
          date: date,
          endsAt: date.add(Duration(hours: hour - 9)),
          condition: kmaCondition(
            int.tryParse(value(item, 'sky') ?? ''),
            int.tryParse(value(item, 'pty') ?? ''),
          ),
          temperature: temperature(item, 'temp'),
          low: temperature(item, 'tmn'),
          high: temperature(item, 'tmx'),
          rainProbability: pop != null && pop >= 0 && pop <= 100 ? pop : null,
        ),
      );
    }
    if (periods.isEmpty) throw const FormatException('Empty KMA forecast');
    periods.sort((a, b) => a.endsAt.compareTo(b.endsAt));
    return WeatherForecast(
      issuedAt: issuedAt,
      fetchedAt: fetchedAt.toUtc(),
      periods: List.unmodifiable(periods),
    );
  }
}
