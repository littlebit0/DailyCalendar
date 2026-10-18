Vendored flutter_inappwebview_windows 0.6.0 from the resolved pub.dev package, license retained.
Only Daily issue #236: per-instance environment channel uses the created environment ID.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analyzer cleanup: rename internal static channel constant; remove unused pull-to-refresh settings local and unreachable return. No native code changes.
Daily #242: createInAppWebView reads headlessWebViewId and, once the visible replacement exists, unregisters and erases the running headless original from the headless manager map (before the visible view registers its channel).
