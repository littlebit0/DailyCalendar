Vendored flutter_inappwebview_macos 1.1.2 from the resolved pub.dev package, license retained.
Daily issue #246: the default WebMessage port/listener handler looks up the channel or listener (and checks the origin) before decoding page input, and decodes it with WebMessage.fromPageMap / WebMessagePort.fromPageMap, which return nil instead of force-casting missing or malformed values. Malformed messages are dropped.
Upstream example and test directories omitted.
Lint: _static_channel.dart carries ignore_for_file: constant_identifier_names because the upstream constant name is kept.
Daily #235: HeadlessInAppWebView adds its zero-frame wrapper through the new HeadlessViewWrapper, which owns that one NSView and removes only it when the view is disposed, including the move to a visible WebView and a repeated prepare. Upstream left one empty wrapper per headless run. Behavior is covered by tool/tests/headless_view_wrapper_test.swift.

Files that differ from upstream (#972; update this list when re-vendoring):
- `macos/Classes/InAppWebView/InAppWebView.swift`, `macos/Classes/Types/WebMessage.swift`, `macos/Classes/Types/WebMessagePort.swift`: #246 (above).
- `macos/Classes/HeadlessInAppWebView/HeadlessInAppWebView.swift` and the new `HeadlessViewWrapper.swift`: #235 (above).
- `lib/src/in_app_webview/headless_in_app_webview.dart`: `internalDispose()` also calls `disposeChannel()` and clears its references after the switch to a visible WebView (#398).
- `lib/src/in_app_webview/_static_channel.dart`: lint ignore (above).
