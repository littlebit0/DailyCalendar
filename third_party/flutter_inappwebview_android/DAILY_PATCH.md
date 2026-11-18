Vendored flutter_inappwebview_android 1.1.3 from the resolved pub.dev package, license retained.
Daily issue #233: InAppWebViewManager.disposeKeepAlive removes the keep-alive key instead of storing null, and dispose() iterates a copy of the keys, tolerating a failing view, so engine detach cannot hit a null dereference.
Upstream example and test directories omitted.
Daily #249: MyCookieManager formats and parses cookie Expires with the 24-hour pattern (HH). The upstream 12-hour pattern (hh, no AM/PM) changed 16:00 UTC to 04:00 and 00:00 to 12:00 when a stored cookie was restored.
Lint: _static_channel.dart carries ignore_for_file: constant_identifier_names because the upstream constant name is kept.

Files that differ from upstream (#972; update this list when re-vendoring):
- `android/src/main/java/.../webview/InAppWebViewManager.java`: #233 (above).
- `android/src/main/java/.../MyCookieManager.java`: #249 (above).
- `android/build.gradle`: release `minifyEnabled` is false and `proguard-rules.pro` uses `-keep,allowshrinking,allowoptimization` with corrected class names, so the app's R8 run keeps only the reachable WebView classes (#402).
- `lib/src/in_app_webview/headless_in_app_webview.dart`: `internalDispose()` also calls `disposeChannel()` and clears its references after the switch to a visible WebView (#398).
- `lib/src/in_app_webview/_static_channel.dart`: lint ignore (above).
