Vendored flutter_inappwebview_windows 0.6.0 from the resolved pub.dev package, license retained.
Only Daily issue #236: per-instance environment channel uses the created environment ID.
Regression tests live under the root test directory. Upstream examples/tests omitted.
Analyzer cleanup: rename internal static channel constant; remove unused pull-to-refresh settings local and unreachable return. No native code changes.
Daily #241: WebMessageReceived parses with exceptions disabled and requires handlerName, _callHandlerID and args before reading them, so an incomplete page message is ignored instead of throwing out of the COM callback.
