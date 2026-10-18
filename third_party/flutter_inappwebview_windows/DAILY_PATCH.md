Vendored flutter_inappwebview_windows 0.6.0 from the resolved pub.dev package, license retained.
Only Daily issue #236: per-instance environment channel uses the created environment ID.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analyzer cleanup: rename internal static channel constant; remove unused pull-to-refresh settings local and unreachable return. No native code changes.
Daily #240: a Dart null success no longer reaches a pointer dereference. The permission-request and JS-handler callbacks decode nullptr/null as "no value", so a missing onPermissionRequest denies once and an unregistered handler resolves JSON null. Navigation, new-window and interception null policies are unchanged.
