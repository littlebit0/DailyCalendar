Vendored flutter_inappwebview_ios 1.1.2 from the resolved pub.dev package, license retained.
Daily issue #246: the default WebMessage port/listener handler looks up the channel or listener (and checks the origin) before decoding page input, and decodes it with WebMessage.fromPageMap / WebMessagePort.fromPageMap, which return nil instead of force-casting missing or malformed values. Malformed messages are dropped.
Upstream example and test directories omitted.
Lint: _static_channel.dart carries ignore_for_file: constant_identifier_names because the upstream constant name is kept.

Files that differ from upstream (#972; update this list when re-vendoring):
- `ios/Classes/InAppWebView/InAppWebView.swift`, `ios/Classes/Types/WebMessage.swift`, `ios/Classes/Types/WebMessagePort.swift`: #246 (above).
- `lib/src/in_app_webview/headless_in_app_webview.dart`: `internalDispose()` also calls `disposeChannel()` and clears its references after the switch to a visible WebView (#398).
- `lib/src/in_app_webview/_static_channel.dart`: lint ignore (above).
