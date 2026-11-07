# WebView
-keepattributes *JavascriptInterface*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
    public void *(android.webkit.webView, jav.lang.String);
}
-keepclassmembers class com.pichillilorenzo.flutter_inappwebview_android.webview.JavaScriptBridgeInterface {
     <fields>;
     <methods>;
     public *;
     private *;
}
# No obfuscation: retained classes and members keep their original names, so name-based
# lookups (Dart method names via WebViewChannelDelegateMethods.valueOf), logs and stack
# traces stay readable. R8 may remove unreachable code and optimize (inline, merge) the
# rest. Manifest components and XML-inflated views are kept by AAPT-generated rules.
-keep,allowshrinking,allowoptimization class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

-dontwarn android.window.BackEvent