import 'package:dbus/dbus.dart';
import 'package:geoclue/geoclue.dart';

const _desktopId = 'com.littlebit0.daily';

Future<bool> _hasLocationConsent() async {
  final bus = DBusClient.session();
  try {
    final store = DBusRemoteObject(
      bus,
      name: 'org.freedesktop.impl.portal.PermissionStore',
      path: DBusObjectPath('/org/freedesktop/impl/portal/PermissionStore'),
    );
    final result = await store
        .callMethod(
          'org.freedesktop.impl.portal.PermissionStore',
          'Lookup',
          [const DBusString('location'), const DBusString('location')],
          replySignature: DBusSignature('a{sas}v'),
        )
        .timeout(const Duration(seconds: 2));
    final permissions = result.values.first.toNative() as Map;
    final entry = permissions[_desktopId];
    return entry is List &&
        entry.isNotEmpty &&
        const {'CITY', 'NEIGHBORHOOD', 'STREET', 'EXACT'}.contains(entry.first);
  } on Object {
    return false;
  } finally {
    await bus.close();
  }
}

Future<({double latitude, double longitude})?> linuxWeatherLocation({
  required bool requestPermission,
}) async {
  // GNOME/GeoClue stores grants under the installed desktop-file ID. If a
  // desktop cannot report a grant, only an explicit user action may prompt.
  if (!requestPermission && !await _hasLocationConsent()) return null;
  final manager = GeoClueManager();
  GeoClueClient? client;
  var cancelled = false;
  try {
    return await (() async {
      await manager.connect();
      if (cancelled) return null;
      final current = await manager.getClient();
      client = current;
      if (cancelled) return null;
      await current.setDesktopId(_desktopId);
      await current.setRequestedAccuracyLevel(GeoClueAccuracyLevel.city);
      if (cancelled) return null;
      await current.start();
      final position = current.location ?? await current.locationUpdated.first;
      if (!position.accuracy.isFinite || position.accuracy > 30000) return null;
      return (latitude: position.latitude, longitude: position.longitude);
    })().timeout(const Duration(seconds: 15));
  } finally {
    cancelled = true;
    try {
      await client?.stop().timeout(const Duration(seconds: 2));
    } on Object {
      /* Closing the bus also releases the GeoClue client. */
    }
    await manager.close();
  }
}
