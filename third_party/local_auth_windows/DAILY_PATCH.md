# Daily Windows authentication patch (#218)

Vendored from pub.dev local_auth_windows 2.0.1 (Flutter packages, BSD-3-Clause;
original LICENSE retained; upstream example, Dart tests and code-generation inputs
omitted, runtime Dart/native sources and native tests retained). Dart API and generated Pigeon files are unchanged.

Both native fire_and_forget entry points now catch synchronous and awaited
availability failures, reply once, and never grant access on error. Authentication
retains the existing failure result; capability checks return a fixed channel error.
No native exception details are exposed. Native regression tests cover both forms
of failure and retry. Remove this override only after an upstream version supplies
and passes equivalent protection. Do not edit the Pub cache to deploy this fix.

Native tests: configure the Windows build with
`-Dinclude_local_auth_windows_tests=ON`, build `local_auth_windows_test`, then run
CTest in `build/windows/x64/plugins/local_auth_windows` with configuration Debug.
