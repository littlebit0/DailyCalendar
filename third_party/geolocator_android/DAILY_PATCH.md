# Daily Android location cancel patch (#228)

Vendored from pub.dev geolocator_android 5.0.3 (MIT; original LICENSE
retained; upstream example and tests omitted).

`cancelGetCurrentPosition` used to stop the native client but left it in the
singleton `GeolocationManager` client list, so a request that timed out without any
callback kept its client (and Context/callbacks) for the process lifetime. The cancel
path now calls `GeolocationManager.stopPositionUpdates`, which removes the client from
the list and then stops it. Other requests and streams are untouched; unknown or
duplicate request IDs remain a no-op. Remove this override only after an upstream
version fixes the cancel path. Do not edit the Pub cache to deploy this fix.

Also (review of #228): `FusedLocationClient.stopPositionUpdates` sets a `stopRequested`
flag, reset by `startPositionUpdates`. A settings check that is still pending when a
request is cancelled can no longer start the updates afterwards (success listener,
failure listener and `onActivityResult` all return when the flag is set), so a
cancelled client is not kept alive by a restarted location request.

Files that differ from upstream (#972; update this list when re-vendoring):
- `android/.../MethodCallHandlerImpl.java`, `android/.../location/FusedLocationClient.java`: #228 (above).
- `android/.../permission/PermissionManager.java`: an empty `grantResults` (cancelled dialog) answers the request once as denied (#395); the request and Activity references are released when it completes or the Activity detaches (#396).
- `android/.../GeolocatorPlugin.java`: keeps a pending permission request across an Activity configuration change and reattaches it to the new Activity (#396).
