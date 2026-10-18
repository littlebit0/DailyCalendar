Vendored flutter_inappwebview_android 1.1.3 from the resolved pub.dev package, license retained.
Only Daily issue #233: InAppWebViewManager.disposeKeepAlive removes the keep-alive key instead of storing null, and dispose() iterates a copy of the keys, tolerating a failing view, so engine detach cannot hit a null dereference.
Upstream example and test directories omitted.
