# Daily Apple location timeout patch (#227)

Vendored from pub.dev geolocator_apple 2.3.14 (BSD-3-Clause; original LICENSE
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
