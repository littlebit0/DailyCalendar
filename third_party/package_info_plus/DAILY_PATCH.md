Vendored package_info_plus 10.2.0 from the resolved pub.dev package, license retained.
Only Daily issue #226: ios/package_info_plus/Sources/package_info_plus/PrivacyInfo.xcprivacy declares NSPrivacyAccessedAPICategoryFileTimestamp with reason 0A2A.1 (a third-party SDK wrapper that reads file dates only when the app calls getAll), because the iOS plugin reads the Documents folder creation date and the app bundle modification date.
Upstream example and test directories omitted.
