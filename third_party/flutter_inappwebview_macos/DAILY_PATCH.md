Vendored flutter_inappwebview_macos 1.1.2 from the resolved pub.dev package, license retained.
Only Daily issue #246: the default WebMessage port/listener handler looks up the channel or listener (and checks the origin) before decoding page input, and decodes it with WebMessage.fromPageMap / WebMessagePort.fromPageMap, which return nil instead of force-casting missing or malformed values. Malformed messages are dropped.
Upstream example and test directories omitted.
