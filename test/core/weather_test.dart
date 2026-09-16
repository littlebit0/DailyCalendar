import 'dart:async';
import 'dart:convert';
import 'package:daily/core/weather/kma_weather_service.dart';
import 'package:daily/core/weather/weather_controller.dart';
import 'package:daily/core/weather/weather_forecast.dart';
import 'package:daily/core/weather/weather_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const seoul = WeatherRegion(
  id: '1100000000',
  name: '서울특별시',
  x: 60,
  y: 127,
  latitude: 37.5635694,
  longitude: 126.9800083,
);
const busan = WeatherRegion(
  id: '2600000000',
  name: '부산광역시',
  x: 98,
  y: 76,
  latitude: 35.18,
  longitude: 129.07,
);
final weatherClock = DateTime.utc(2026, 9, 11, 12);

String weatherXml({
  WeatherRegion region = seoul,
  String time = '202609112000',
  String temperature = '20',
  String sky = '3',
  String pty = '0',
}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<wid><header><tm>$time</tm><x>${region.x}</x><y>${region.y}</y></header><body>
<data><hour>24</hour><day>0</day><temp>$temperature</temp><tmn>-999.0</tmn><tmx>-999.0</tmx><sky>$sky</sky><pty>$pty</pty><pop>20</pop></data>
<data><hour>9</hour><day>1</day><temp>22</temp><tmn>17</tmn><tmx>28</tmx><sky>1</sky><pty>0</pty><pop>0</pop></data>
<data><hour>18</hour><day>1</day><temp>25</temp><tmn>17</tmn><tmx>28</tmx><sky>4</sky><pty>1</pty><pop>70</pop></data>
</body></wid>''';

class TestWeatherService extends KmaWeatherService {
  int requests = 0;
  Future<String> Function(WeatherRegion region)? answer;
  @override
  Future<List<WeatherRegion>> regions() async => [seoul, busan];
  @override
  Future<String> fetch(WeatherRegion region) {
    requests++;
    return answer?.call(region) ?? Future.value(weatherXml(region: region));
  }
}

class TestWeatherLocation implements WeatherLocation {
  final permissionRequests = <bool>[];
  ({double latitude, double longitude})? point;
  @override
  Future<({double latitude, double longitude})?> current({
    required bool requestPermission,
  }) async {
    permissionRequests.add(requestPermission);
    return point;
  }
}

class FailingWeatherStore extends WeatherStore {
  FailingWeatherStore(super.preferences);
  bool fail = false;
  @override
  Future<void> save(WeatherSettings settings) {
    if (fail) return Future.error(StateError('storage unavailable'));
    return super.save(settings);
  }
}

Future<WeatherStore> weatherStore([
  WeatherSettings settings = const WeatherSettings(),
]) async {
  SharedPreferences.setMockInitialValues({});
  final store = WeatherStore(await SharedPreferences.getInstance());
  await store.save(settings);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KMA XML keeps hour 24 on forecast day, sentinel values are absent', () {
    final forecast = WeatherForecast.parse(
      weatherXml(),
      fetchedAt: weatherClock,
      region: seoul,
    );
    final today = forecast.forDate(DateTime(2026, 9, 11), weatherClock)!;
    expect(today.temperature, 20);
    expect(today.low, isNull);
    expect(today.high, isNull);
    expect(today.condition, WeatherCondition.partlyCloudy);
    expect(forecast.periods.first.endsAt, DateTime.utc(2026, 9, 11, 15));
    final tomorrow = forecast.forDate(DateTime(2026, 9, 12), weatherClock)!;
    expect(tomorrow.low, 17);
    expect(tomorrow.high, 28);
    expect(tomorrow.rainProbability, 70);
    expect(tomorrow.condition, WeatherCondition.rain);
  });

  test('all KMA precipitation codes and unknown values are normalized', () {
    expect(
      [for (var pty = 0; pty <= 7; pty++) kmaCondition(1, pty)],
      [
        WeatherCondition.clear,
        WeatherCondition.rain,
        WeatherCondition.sleet,
        WeatherCondition.snow,
        WeatherCondition.shower,
        WeatherCondition.rain,
        WeatherCondition.sleet,
        WeatherCondition.snow,
      ],
    );
    expect(kmaCondition(4, 0), WeatherCondition.cloudy);
    expect(kmaCondition(42, 0), WeatherCondition.unknown);
    expect(kmaCondition(1, 42), WeatherCondition.unknown);
    expect(kmaCondition(null, null), WeatherCondition.unknown);
  });

  test(
    'does not fabricate past, distant future, expired or invalid forecasts',
    () {
      final forecast = WeatherForecast.parse(
        weatherXml(temperature: '-999', sky: '99'),
        fetchedAt: weatherClock,
        region: seoul,
      );
      expect(forecast.forDate(DateTime(2026, 9, 10), weatherClock), isNull);
      expect(forecast.forDate(DateTime(2026, 10, 1), weatherClock), isNull);
      expect(
        forecast.forDate(
          DateTime(2026, 9, 12),
          weatherClock.add(const Duration(hours: 13)),
        ),
        isNull,
      );
      expect(
        forecast.forDate(DateTime(2026, 9, 11), weatherClock)!.temperature,
        isNull,
      );
      expect(
        () => WeatherForecast.parse(
          '<html>Error</html>',
          fetchedAt: weatherClock,
          region: seoul,
        ),
        throwsA(anything),
      );
      expect(
        () => WeatherForecast.parse(
          weatherXml(region: busan),
          fetchedAt: weatherClock,
          region: seoul,
        ),
        throwsFormatException,
      );
      expect(
        () => WeatherForecast.parse(
          weatherXml(time: '202613112000'),
          fetchedAt: weatherClock,
          region: seoul,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'Korea forecast date is independent from device timezone and UTC midnight',
    () {
      final forecast = WeatherForecast.parse(
        weatherXml(),
        fetchedAt: weatherClock,
        region: seoul,
      );
      expect(
        forecast.forDate(DateTime(2026, 9, 11), DateTime.utc(2026, 9, 11, 15)),
        isNull,
      );
      expect(
        forecast.forDate(DateTime(2026, 9, 12), DateTime.utc(2026, 9, 11, 15)),
        isNotNull,
      );
      expect(koreaNow(DateTime.utc(2026, 12, 31, 16)).year, 2027);
    },
  );

  test('official offline region index includes all Korean districts', () async {
    final regions = await KmaWeatherService().regions();
    expect(regions.length, greaterThan(3000));
    expect(regions.map((r) => r.id).toSet().length, regions.length);
    expect(regions.firstWhere((r) => r.id == seoul.id).gridKey, '60,127');
    expect(regions.any((r) => r.name.contains('제주')), isTrue);
    expect(
      nearestWeatherRegion(regions, seoul.latitude, seoul.longitude)?.gridKey,
      '60,127',
    );
    expect(nearestWeatherRegion(regions, 35.68, 139.69), isNull);
  });

  test(
    'request sends only a grid over HTTPS, not identity or raw location',
    () async {
      final service = KmaWeatherService(
        clientFactory: () => MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'www.kma.go.kr');
          expect(request.url.queryParameters, {'gridx': '60', 'gridy': '127'});
          expect(request.headers['authorization'], isNull);
          return http.Response.bytes(utf8.encode(weatherXml()), 200);
        }),
      );
      expect(await service.fetch(seoul), weatherXml());
    },
  );

  test('disabled weather never calls network or location', () async {
    final service = TestWeatherService();
    final location = TestWeatherLocation();
    final controller = WeatherController(
      store: await weatherStore(),
      service: service,
      location: location,
      clock: () => weatherClock,
    );
    addTearDown(controller.dispose);
    await controller.refresh(force: true, requestPermission: true);
    expect(service.requests, 0);
    expect(location.permissionRequests, isEmpty);
  });

  test(
    'background blocks work; foreground resumes one shared request',
    () async {
      final service = TestWeatherService();
      final controller = WeatherController(
        store: await weatherStore(
          const WeatherSettings(enabled: true, regionId: '1100000000'),
        ),
        service: service,
        location: TestWeatherLocation(),
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      controller.setForeground(false);
      await controller.refresh(force: true);
      expect(service.requests, 0);
      controller.setForeground(true);
      await controller.refresh();
      expect(service.requests, 1);
    },
  );

  test('failed setting write preserves the prior visible forecast', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FailingWeatherStore(await SharedPreferences.getInstance());
    await store.save(
      const WeatherSettings(enabled: true, regionId: '1100000000'),
    );
    final controller = WeatherController(
      store: store,
      service: TestWeatherService(),
      location: TestWeatherLocation(),
      clock: () => weatherClock,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final previous = controller.forecast;
    store.fail = true;
    await controller.configure(controller.settings.copyWith(enabled: false));
    expect(controller.settings.enabled, isTrue);
    expect(controller.forecast, same(previous));
    expect(controller.status, WeatherStatus.storageError);
  });

  test(
    'enabled manual location uses cache, merges requests, and refreshes on region change',
    () async {
      final service = TestWeatherService();
      final pending = Completer<String>();
      service.answer = (_) => pending.future;
      final controller = WeatherController(
        store: await weatherStore(
          const WeatherSettings(enabled: true, regionId: '1100000000'),
        ),
        service: service,
        location: TestWeatherLocation(),
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      final first = controller.refresh();
      final second = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(service.requests, 1);
      pending.complete(weatherXml());
      await first;
      await second;
      await controller.refresh();
      expect(service.requests, 1);
      service.answer = (region) async => weatherXml(region: region);
      await controller.configure(
        controller.settings.copyWith(regionId: busan.id),
      );
      expect(service.requests, 2);
      expect(controller.region?.id, busan.id);
    },
  );

  test(
    'disable rejects a late response and retains the selected region',
    () async {
      final pending = Completer<String>();
      final service = TestWeatherService()..answer = (_) => pending.future;
      final store = await weatherStore(
        const WeatherSettings(enabled: true, regionId: '1100000000'),
      );
      final controller = WeatherController(
        store: store,
        service: service,
        location: TestWeatherLocation(),
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      final work = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await controller.configure(controller.settings.copyWith(enabled: false));
      pending.complete(weatherXml());
      await work;
      expect(controller.forecast, isNull);
      expect(controller.settings.regionId, seoul.id);
      expect(store.cached(seoul.gridKey), isNull);
      expect(controller.forDate(DateTime(2026, 9, 11)), isNull);
    },
  );

  test('old region response cannot replace a newer selection', () async {
    final pending = Completer<String>();
    final service = TestWeatherService()
      ..answer = (region) => region.id == seoul.id
          ? pending.future
          : Future.value(weatherXml(region: region));
    final controller = WeatherController(
      store: await weatherStore(
        const WeatherSettings(enabled: true, regionId: '1100000000'),
      ),
      service: service,
      location: TestWeatherLocation(),
      clock: () => weatherClock,
    );
    addTearDown(controller.dispose);
    final work = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.configure(
      controller.settings.copyWith(regionId: busan.id),
    );
    pending.complete(weatherXml());
    await work;
    expect(controller.region?.id, busan.id);
    expect(controller.status, WeatherStatus.ready);
  });

  test(
    'permission is requested only by explicit action; denial falls back to manual region',
    () async {
      final location = TestWeatherLocation();
      final controller = WeatherController(
        store: await weatherStore(
          const WeatherSettings(enabled: true, regionId: '1100000000'),
        ),
        service: TestWeatherService(),
        location: location,
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      await controller.configure(
        controller.settings.copyWith(automaticLocation: true),
      );
      expect(location.permissionRequests, [true]);
      expect(controller.usingManualFallback, isTrue);
      expect(controller.region?.id, seoul.id);
      await controller.refresh();
      expect(location.permissionRequests, [true, false]);
    },
  );

  test(
    'saved automatic setting does not trigger permission prompts at startup',
    () async {
      final location = TestWeatherLocation();
      final service = TestWeatherService();
      final controller = WeatherController(
        store: await weatherStore(
          const WeatherSettings(enabled: true, automaticLocation: true),
        ),
        service: service,
        location: location,
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(location.permissionRequests, [false]);
      expect(service.requests, 0);
      expect(controller.status, WeatherStatus.locationUnavailable);
    },
  );

  test(
    'offline failure retains valid cache; expired cache disappears',
    () async {
      final store = await weatherStore(
        const WeatherSettings(enabled: true, regionId: '1100000000'),
      );
      await store.cache(seoul.gridKey, weatherXml(), weatherClock);
      var now = weatherClock.add(const Duration(hours: 4));
      final service = TestWeatherService()
        ..answer = (_) async => throw StateError('offline');
      final controller = WeatherController(
        store: store,
        service: service,
        location: TestWeatherLocation(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.status, WeatherStatus.unavailable);
      expect(controller.forDate(DateTime(2026, 9, 12)), isNotNull);
      now = now.add(const Duration(hours: 10));
      await controller.refresh();
      expect(controller.forDate(DateTime(2026, 9, 12)), isNull);
    },
  );

  test(
    'local reset cancels forecast state and removes region and cached weather',
    () async {
      final store = await weatherStore(
        const WeatherSettings(enabled: true, regionId: '1100000000'),
      );
      final controller = WeatherController(
        store: store,
        service: TestWeatherService(),
        location: TestWeatherLocation(),
        clock: () => weatherClock,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await store.clear();
      expect(controller.settings.enabled, isFalse);
      expect(controller.forecast, isNull);
      expect(store.load().regionId, isNull);
      expect(store.cached(seoul.gridKey), isNull);
    },
  );
}
