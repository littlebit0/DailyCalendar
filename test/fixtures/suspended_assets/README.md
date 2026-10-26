# Suspended timetable datasets

Timetable data of universities whose course search is suspended
(`UniversitySupportPolicy.suspendedTimetableUniversities`) is not shipped in
`assets/timetable/`: the files are large and unreachable in the app.

They are kept here, byte for byte, so their tests keep running through
`test/support/suspended_assets.dart` (`SuspendedAssetBundle`).

Each `timetable/<university>.catalog.json` lists the dataset paths exactly as they appear in
`assets/timetable/catalog.json` when a university is supported. To resume
support, move the files back and register them (see the doc comment in
`test/support/suspended_assets.dart`).
