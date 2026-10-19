Vendored flutter_inappwebview_windows 0.6.0 from the resolved pub.dev package, license retained.
Only Daily issue #236: per-instance environment channel uses the created environment ID.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analyzer cleanup: rename internal static channel constant; remove unused pull-to-refresh settings local and unreachable return. No native code changes.
Daily #242: createInAppWebView reads headlessWebViewId and, once the visible replacement exists, unregisters and erases the running headless original from the headless manager map (before the visible view registers its channel).
Daily #241: WebMessageReceived parses with exceptions disabled and requires handlerName, _callHandlerID and args before reading them, so an incomplete page message is ignored instead of throwing out of the COM callback.
Daily #240: a Dart null success no longer reaches a pointer dereference. The permission-request and JS-handler callbacks decode nullptr/null as "no value", so a missing onPermissionRequest denies once and an unregistered handler resolves JSON null. Navigation, new-window and interception null policies are unchanged.
Daily #244: the GraphicsCapture activation factories (session support check in `in_app_webview_manager.cpp`; capture item, frame pool and free-threaded frame pool in `custom_platform_view/graphics_context.cc`) are received into `winrt::com_ptr` with `put_void()`, so the caller's reference is released on success, failure and exceptions. Upstream kept raw out-pointers and never released them.
