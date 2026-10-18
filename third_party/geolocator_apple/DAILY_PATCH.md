# Daily Apple location timeout patch (#227)

Vendored from pub.dev geolocator_apple 2.3.14 (MIT; original LICENSE
retained; upstream example and tests omitted).

A `getCurrentPosition` call with a time limit used to end only the Dart future; the
native one-time `CLLocationManager` kept running `startUpdatingLocation` until a fresh
location or a terminal error arrived. On timeout the Dart side now sends
`cancelGetCurrentPosition` (best effort) and the plugin calls
`GeolocationHandler stopOneTimeLocationListening`, which stops the manager and drops
the stored result/error handlers. The timeout is still reported as a
`TimeoutException`. Position streams and the stream manager are untouched. Remove this
override only after an upstream version cancels one-time requests on timeout. Do not
edit the Pub cache to deploy this fix.

Review of #227: each one-time request carries a `requestId` (an in-process counter)
in `getCurrentPosition`, and `cancelGetCurrentPosition` sends the same id. The
native handler stops the shared one-time manager only when that id still owns it
(`cancelOneTimeRequestWithId:`), so an older lookup timing out cannot stop a newer
one that took over the manager. The id is local to the app run and never leaves the
device. The native behaviour is covered by `tool/tests/geolocator_apple_handler_test.m`
(run by `tool/tests/test_geolocator_apple_cancel.py`).
