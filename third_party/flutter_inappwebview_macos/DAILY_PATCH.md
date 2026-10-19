Vendored flutter_inappwebview_macos 1.1.2 from the resolved pub.dev package, license retained.
Only Daily issue #246: the default WebMessage port/listener handler looks up the channel or listener (and checks the origin) before decoding page input, and decodes it with WebMessage.fromPageMap / WebMessagePort.fromPageMap, which return nil instead of force-casting missing or malformed values. Malformed messages are dropped.
Upstream example and test directories omitted.
Lint: _static_channel.dart carries ignore_for_file: constant_identifier_names because the upstream constant name is kept.
Daily #235: HeadlessInAppWebView keeps the zero-frame wrapper NSView it adds to the main window's content view and removes only that wrapper when it is disposed, including the move to a visible WebView and a repeated prepare. Upstream left one empty wrapper per headless run.
