// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include <winstring.h>

#include "local_auth.h"
#include "messages.g.h"

namespace {

// Returns the window's HWND for a given FlutterView.
HWND GetRootWindow(flutter::FlutterView* view) {
  return ::GetAncestor(view->GetNativeWindow(), GA_ROOT);
}

// Converts the given UTF-8 string to UTF-16.
std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  int target_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  int converted_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()),
                            utf16_string.data(), target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

}  // namespace

namespace local_auth_windows {

// Creates an instance of the UserConsentVerifier that
// calls the native Windows APIs to get the user's consent.
class UserConsentVerifierImpl : public UserConsentVerifier {
 public:
  explicit UserConsentVerifierImpl(std::function<HWND()> window_provider)
      : get_root_window_(std::move(window_provider)) {}
  virtual ~UserConsentVerifierImpl() = default;

  // Calls the native Windows API to get the user's consent
  // with the provided reason.
  winrt::Windows::Foundation::IAsyncOperation<
      winrt::Windows::Security::Credentials::UI::UserConsentVerificationResult>
  RequestVerificationForWindowAsync(std::wstring localized_reason) override {
    winrt::impl::com_ref<IUserConsentVerifierInterop>
        user_consent_verifier_interop = winrt::get_activation_factory<
            winrt::Windows::Security::Credentials::UI::UserConsentVerifier,
            IUserConsentVerifierInterop>();

    HWND root_window_handle = get_root_window_();

    auto reason = wil::make_unique_string<wil::unique_hstring>(
        localized_reason.c_str(), localized_reason.size());

    winrt::Windows::Security::Credentials::UI::UserConsentVerificationResult
        consent_result = co_await winrt::capture<
            winrt::Windows::Foundation::IAsyncOperation<
                winrt::Windows::Security::Credentials::UI::
                    UserConsentVerificationResult>>(
            user_consent_verifier_interop,
            &::IUserConsentVerifierInterop::RequestVerificationForWindowAsync,
            root_window_handle, reason.get());

    return consent_result;
  }

  // Calls the native Windows API to check for the Windows Hello availability.
  winrt::Windows::Foundation::IAsyncOperation<
      winrt::Windows::Security::Credentials::UI::
          UserConsentVerifierAvailability>
  CheckAvailabilityAsync() override {
    return winrt::Windows::Security::Credentials::UI::UserConsentVerifier::
        CheckAvailabilityAsync();
  }

  // Disallow copy and move.
  UserConsentVerifierImpl(const UserConsentVerifierImpl&) = delete;
  UserConsentVerifierImpl& operator=(const UserConsentVerifierImpl&) = delete;

 private:
  // The provider for the root window to attach the dialog to.
  std::function<HWND()> get_root_window_;
};

// static
void LocalAuthPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<LocalAuthPlugin>(
      [registrar]() { return GetRootWindow(registrar->GetView()); });
  LocalAuthApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

// Default constructor for LocalAuthPlugin.
LocalAuthPlugin::LocalAuthPlugin(std::function<HWND()> window_provider)
    : user_consent_verifier_(std::make_unique<UserConsentVerifierImpl>(
          std::move(window_provider))) {}

LocalAuthPlugin::LocalAuthPlugin(
    std::unique_ptr<UserConsentVerifier> user_consent_verifier)
    : user_consent_verifier_(std::move(user_consent_verifier)) {}

LocalAuthPlugin::~LocalAuthPlugin() {}

void LocalAuthPlugin::IsDeviceSupported(
    std::function<void(ErrorOr<bool> reply)> result) {
  IsDeviceSupportedCoroutine(std::move(result));
}

void LocalAuthPlugin::Authenticate(
    const std::string& localized_reason,
    std::function<void(ErrorOr<AuthResult> reply)> result) {
  AuthenticateCoroutine(localized_reason, std::move(result));
}

// Starts authentication process.
winrt::fire_and_forget LocalAuthPlugin::AuthenticateCoroutine(
    const std::string& localized_reason,
    std::function<void(ErrorOr<AuthResult> reply)> result) {
  ErrorOr<AuthResult> reply(AuthResult::kFailure);
  try {
    // Copy before the first suspension; the caller owns localized_reason.
    const std::wstring reason = Utf16FromUtf8(localized_reason);
    using Availability = winrt::Windows::Security::Credentials::UI::
        UserConsentVerifierAvailability;
    const auto availability =
        co_await user_consent_verifier_->CheckAvailabilityAsync();
    switch (availability) {
      case Availability::DeviceNotPresent:
        reply = AuthResult::kNoHardware;
        break;
      case Availability::NotConfiguredForUser:
        reply = AuthResult::kNotEnrolled;
        break;
      case Availability::DeviceBusy:
        reply = AuthResult::kDeviceBusy;
        break;
      case Availability::DisabledByPolicy:
        reply = AuthResult::kDisabledByPolicy;
        break;
      case Availability::Available: {
        const auto consent = co_await user_consent_verifier_
            ->RequestVerificationForWindowAsync(reason);
        reply = consent == winrt::Windows::Security::Credentials::UI::
                               UserConsentVerificationResult::Verified
                    ? AuthResult::kSuccess
                    : AuthResult::kFailure;
        break;
      }
      default:
        reply = AuthResult::kUnavailable;
    }
  } catch (...) {
    // fire_and_forget terminates the process for uncaught WinRT failures.
    // Never turn an availability/verification error into authentication success.
    reply = AuthResult::kFailure;
  }
  // Reply exactly once, outside the catch protecting native operations.
  result(reply);
}

// Returns whether the device supports Windows Hello or not.
winrt::fire_and_forget LocalAuthPlugin::IsDeviceSupportedCoroutine(
    std::function<void(ErrorOr<bool> reply)> result) {
  ErrorOr<bool> reply(false);
  try {
    const auto availability =
        co_await user_consent_verifier_->CheckAvailabilityAsync();
    reply = availability == winrt::Windows::Security::Credentials::UI::
                                UserConsentVerifierAvailability::Available;
  } catch (...) {
    reply = FlutterError("availability_error",
                         "Windows Hello availability check failed.");
  }
  result(reply);
}

}  // namespace local_auth_windows
