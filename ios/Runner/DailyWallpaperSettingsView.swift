import SwiftUI
import UIKit
import UserNotifications

@available(iOS 16.0, *)
struct DailyWallpaperSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // UIKit presents this view above Flutter, without a SwiftUI App/Scene.
  @State private var appIsActive = UIApplication.shared.applicationState == .active
  @State private var settings = DailyWallpaperStore.settings
  @State private var progress = DailyWallpaperStore.progress
  @State private var step = DailyWallpaperStore.progress.stage
  @State private var preview: UIImage?
  @State private var previewSuppressed = false
  @State private var error: String?
  @State private var busy = false
  @State private var photoSaved = false
  @State private var showConsent = false
  @State private var showOptions = false
  @State private var afterOptions: OptionsDestination?
  @State private var showRemoval = false
  @State private var showTroubleshooting = false
  @State private var guide: WallpaperGuideKind?
  @State private var file: WallpaperShareFile?
  @State private var updateAttempt = DailyWallpaperUpdateMonitor.attempts.latest
  @State private var notificationsAllowed = true
  @State private var generatedAt = UserDefaults.standard.double(forKey: DailyWallpaperStore.generatedKey)

  private func t(_ key: String) -> String { DailyWallpaperText.value(key) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          stepIndicator
          VStack(alignment: .leading, spacing: 10) {
            Text(t("setupTitle\(step)")).font(.title2.bold())
            Text(t("setupBody\(step)")).foregroundStyle(.secondary)
          }.fixedSize(horizontal: false, vertical: true)
          WallpaperPreview(image: preview)
          stepContent
          if let error {
            Label(error, systemImage: "exclamationmark.circle")
              .font(.callout).foregroundStyle(.red)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: 560)
        .padding(24)
        .frame(maxWidth: .infinity)
      }
      .background(Color(uiColor: .systemBackground))
      .safeAreaInset(edge: .bottom, spacing: 0) { actions }
      .navigationTitle(t("title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(t("done")) { dismiss() } }
        ToolbarItem(placement: .primaryAction) {
          Button { showOptions = true } label: { Image(systemName: "slider.horizontal.3") }
            .accessibilityLabel(t("options"))
        }
      }
      .task { await refreshUpdateStatus(); await updatePreview() }
      .onReceive(NotificationCenter.default.publisher(for: DailyWallpaperUpdateMonitor.changed)) { _ in
        Task { await refreshUpdateStatus() }
      }
      .onAppear { appIsActive = UIApplication.shared.applicationState == .active }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
        appIsActive = false
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
        if UserDefaults.standard.bool(forKey: "flutter.appLockEnabled") { dismiss() }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        appIsActive = true
        settings = DailyWallpaperStore.settings
        Task { await refreshUpdateStatus(); await updatePreview() }
      }
      .alert(t("privacyTitle"), isPresented: $showConsent) {
        Button(t("cancel"), role: .cancel) {}
        Button(t("enable")) { change { $0.enabled = true; $0.consentAccepted = true } }
      } message: { Text(t("privacy")) }
      .sheet(item: $guide) { WallpaperScreenGuide(kind: $0, preview: preview) }
      // Dismissing sharing is not an installation receipt. Confirmation stays explicit.
      .sheet(item: $file) { WallpaperFileShare(url: $0.url) }
      .sheet(isPresented: $showOptions, onDismiss: finishOptions) { options }
      .sheet(isPresented: $showRemoval) {
        DailyWallpaperRemovalView {
          previewSuppressed = true
          preview = nil
          settings = DailyWallpaperStore.settings
          progress = DailyWallpaperStore.progress
          step = 0
          photoSaved = false
        }
      }
    }
    .opacity(appIsActive ? 1 : 0)
    .allowsHitTesting(appIsActive)
    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    .environment(\.locale, DailyWallpaperText.locale)
    .preferredColorScheme(appColorScheme)
  }

  private var stepIndicator: some View {
    HStack(alignment: .top, spacing: 8) {
      ForEach(0..<4) { index in
        Button {
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            step = index
            error = nil
          }
        } label: {
          VStack(spacing: 8) {
            ZStack {
              Circle().fill(index == step ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
              if index < progress.stage {
                Image(systemName: "checkmark").font(.caption.bold())
              } else { Text("\(index + 1)").font(.subheadline.bold()) }
            }
            .foregroundStyle(index == step ? Color.white : Color.primary)
            .frame(width: 32, height: 32)
            Text(t("stage\(index)")).font(.caption.weight(index == step ? .semibold : .regular))
              .foregroundStyle(index == step ? Color.primary : Color.secondary)
              .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
          }.frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
        }
        .buttonStyle(.plain)
        .disabled(index > progress.stage || busy)
        .accessibilityLabel("\(index + 1). \(t("stage\(index)"))")
        .accessibilityAddTraits(index == step ? [.isSelected] : [])
      }
    }
  }

  @ViewBuilder private var stepContent: some View {
    switch step {
    case 0:
      if photoSaved {
        Label(t("photoSaved"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        Text(t("photoSavedHelp")).foregroundStyle(.secondary)
      }
      Button { guide = .photo } label: {
        Label(t("photoGuide"), systemImage: "rectangle.portrait.and.arrow.right")
      }
      Text(t("photoPrivacy")).font(.footnote).foregroundStyle(.secondary)
    case 1:
      Label(DailyWallpaperStore.shortcutName, systemImage: "square.stack.3d.up.fill")
        .font(.headline).fixedSize(horizontal: false, vertical: true)
      Text(t("shortcutReplaceNote")).foregroundStyle(.primary)
      Text(t("shortcutImportHelp")).font(.callout).foregroundStyle(.secondary)
      Button { guide = .photo } label: {
        Label(t("wallpaperSelectionHelp"), systemImage: "photo")
      }
    case 2:
      if let updateAttempt {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
          let outcome = updateAttempt.visibleOutcome(now: context.date)
          VStack(alignment: .leading, spacing: 8) {
            Label(t("update_\(outcome.rawValue)"), systemImage: outcome == .systemReported ? "checkmark.circle" : "info.circle")
              .font(.headline)
            Text(t(outcome == .systemReported ? "updateReportedHelp" :
                   outcome == .waiting ? "updateWaitingHelp" : "updateFailureHelp"))
              .font(.callout).foregroundStyle(.secondary)
          }
        }
      } else { Text(t("updateNotVerified")).font(.callout).foregroundStyle(.secondary) }
      DisclosureGroup(t("visibleNo"), isExpanded: $showTroubleshooting) {
        VStack(alignment: .leading, spacing: 16) {
          Text(t("notVisibleHelp")).font(.callout)
          Button { guide = .photo } label: { Label(t("photoGuide"), systemImage: "photo") }
          Button { replaceShortcut() } label: { Label(t("shortcutReplace"), systemImage: "arrow.triangle.2.circlepath") }
          #if targetEnvironment(simulator)
          Text(t("simulatorNote")).font(.footnote).foregroundStyle(.secondary)
          #endif
        }.padding(.top, 12)
      }
    default:
      Label(t("visualConfirmed"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
      if progress.automationReady {
        Label(t("automationConfirmed"), systemImage: "checkmark.circle")
        Text(t("status")).font(.footnote).foregroundStyle(.secondary)
      }
      Text(t("timing")).font(.callout).foregroundStyle(.secondary)
      Button { openShortcut() } label: { Label(t("applyNow"), systemImage: "arrow.clockwise") }
        .disabled(!settings.enabled)
    }
  }

  private var actions: some View {
    VStack(spacing: 12) {
      Button(action: primaryAction) {
        HStack(spacing: 10) {
          if busy { ProgressView().tint(.white) }
          else { Image(systemName: primaryIcon) }
          Text(primaryTitle).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 38)
      }
      .buttonStyle(.borderedProminent).controlSize(.large)
      .disabled(busy || (step == 0 && settings.enabled && preview == nil))
      if settings.enabled {
        Button(t(["photoReady", "shortcutReady", "visibleYes", "automationReady"][step])) {
          confirmStep()
        }
        .font(.callout.weight(.semibold)).frame(minHeight: 32).disabled(busy)
        if step == 3 && !progress.automationReady {
          Button(t("later")) { dismiss() }.font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: 560).padding(.horizontal, 24).padding(.vertical, 12)
    .frame(maxWidth: .infinity).background(.regularMaterial)
  }

  private var primaryTitle: String {
    if !settings.enabled { return t("enable") }
    return t([photoSaved ? "photoGuide" : "savePhoto", "shortcutReplace", "applyNow", "automationGuide"][step])
  }
  private var primaryIcon: String {
    !settings.enabled ? "lock.shield" : [photoSaved ? "photo" : "square.and.arrow.down", "square.and.arrow.down", "play.fill", "bolt"][step]
  }
  private func primaryAction() {
    error = nil
    guard settings.enabled else {
      if settings.consentAccepted { change { $0.enabled = true } }
      else { showConsent = true }
      return
    }
    switch step {
    case 0:
      if photoSaved { guide = .photo; return }
      busy = true
      Task {
        defer { busy = false }
        do { try await DailyWallpaperStore.savePhoto(); photoSaved = true }
        catch is CancellationError {} catch { self.error = error.localizedDescription }
      }
    case 1: install(name: DailyWallpaperStore.shortcutName)
    case 2: openShortcut()
    default: guide = .automation
    }
  }

  private func confirmStep() {
    var next = progress
    switch step {
    case 0: next.confirmPhoto()
    case 1: next.confirmShortcut()
    case 2: next.confirmVisible()
    default: next.confirmAutomation()
    }
    guard saveProgress(next) else { return }
    if step == 3 { dismiss() }
    else { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = next.stage } }
  }

  private var options: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(t("enable"), isOn: Binding(get: { settings.enabled }, set: { value in
            if value && !settings.consentAccepted { afterOptions = .consent; showOptions = false }
            else { change { $0.enabled = value } }
          }))
          if !notificationsAllowed {
            Button { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } label: {
              Label(t("updateNotificationsOff"), systemImage: "bell.slash")
            }
          }
          Button { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } label: {
            Label(t("settingsApp"), systemImage: "gearshape")
          }
          if generatedAt > 0 {
            LabeledContent(t("generated"), value: Date(timeIntervalSince1970: generatedAt)
              .formatted(date: .abbreviated, time: .shortened))
          }
        }
        Section(t("design")) {
          Picker(t("appearance"), selection: Binding(get: { settings.appearance }, set: { value in
            change { $0.appearance = value }
          })) {
            Text(t("dark")).tag("dark")
            Text(t("light")).tag("light")
          }.pickerStyle(.segmented)
          Text(t("position"))
          Slider(value: $settings.topFraction, in: 0.34...0.52, step: 0.01, onEditingChanged: { editing in
            if !editing { change { _ in } }
          }).accessibilityLabel(t("position"))
          Text(t("layoutNote")).font(.footnote).foregroundStyle(.secondary)
          WallpaperPreview(image: preview)
          Button { previewSuppressed = false; Task { await updatePreview() } } label: {
            Label(t("refresh"), systemImage: "arrow.clockwise")
          }
        }
        Section {
          Button(t("shortcutReplace")) { showOptions = false; replaceShortcut() }
          Button(t("setupRestart")) {
            var next = progress
            next.repeatFromPhoto()
            guard saveProgress(next) else { return }
            step = 0
            photoSaved = false
            showOptions = false
          }
        }
        Section(t("optionalHelper")) {
          Button(t("addHelper")) { afterOptions = .helper; showOptions = false }
          Button(t("runHelper")) {
            DailyWallpaperLinks.run(name: DailyWallpaperStore.setupShortcutName) { if !$0 { error = t("openError") } }
          }
        }
        Section {
          Button(role: .destructive) {
            change { $0.enabled = false }
            afterOptions = .removal
            showOptions = false
          } label: { Label(t("remove"), systemImage: "trash") }
        }
      }
      .navigationTitle(t("options")).navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("done")) { showOptions = false } } }
    }
  }

  private var appColorScheme: ColorScheme? {
    switch UserDefaults.standard.string(forKey: "flutter.themeMode") {
    case "dark": .dark
    case "light": .light
    default: nil
    }
  }
  private enum OptionsDestination { case consent, helper, removal }
  private func finishOptions() {
    let destination = afterOptions
    afterOptions = nil
    switch destination {
    case .consent: showConsent = true
    case .helper: install(name: DailyWallpaperStore.setupShortcutName)
    case .removal: showRemoval = true
    case nil: break
    }
  }
  private func change(_ mutate: (inout DailyWallpaperSettings) -> Void) {
    mutate(&settings)
    do { try DailyWallpaperStore.save(settings); Task { await updatePreview() } }
    catch { self.error = error.localizedDescription }
  }
  private func saveProgress(_ value: DailyWallpaperSetupProgress) -> Bool {
    do { try DailyWallpaperStore.saveProgress(value); progress = value; return true }
    catch { self.error = error.localizedDescription; return false }
  }
  private func replaceShortcut() {
    var next = progress
    next.replaceShortcut()
    guard saveProgress(next) else { return }
    step = next.stage
  }
  private func install(name: String) {
    guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else { error = t("installError"); return }
    file = WallpaperShareFile(url: url)
  }
  private func updatePreview() async {
    guard !previewSuppressed else { return }
    do {
      let data = try await DailyWallpaperStore.image(preview: true)
      guard !previewSuppressed, !Task.isCancelled else { return }
      preview = UIImage(data: data)
    } catch is CancellationError {} catch { self.error = t("dataError") }
  }
  private func openShortcut() {
    DailyWallpaperLinks.run { if !$0 { error = t("openError") } }
  }
  private func refreshUpdateStatus() async {
    updateAttempt = DailyWallpaperUpdateMonitor.attempts.latest
    generatedAt = UserDefaults.standard.double(forKey: DailyWallpaperStore.generatedKey)
    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    notificationsAllowed = status == .authorized || status == .provisional || status == .ephemeral
  }
}

private struct WallpaperPreview: View {
  let image: UIImage?
  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1))
      } else { ProgressView().frame(width: 110, height: 240) }
    }
    .frame(maxWidth: .infinity, maxHeight: 240)
    .accessibilityLabel(DailyWallpaperText.value("preview"))
  }
}

private enum WallpaperGuideKind: String, Identifiable {
  case photo, automation
  var id: String { rawValue }
}

// A bounded, interactive illustration, never an overlay on another app.
// Tapping its controls advances the illustration only, not setup completion.
@available(iOS 16.0, *)
private struct WallpaperScreenGuide: View {
  let kind: WallpaperGuideKind
  let preview: UIImage?
  @Environment(\.dismiss) private var dismiss
  @AppStorage(DailyWallpaperStore.photoGuidePageKey) private var photoPage = 0
  @AppStorage(DailyWallpaperStore.automationGuidePageKey) private var automationPage = 0
  @State private var error: String?
  private func t(_ key: String) -> String { DailyWallpaperText.value(key) }
  private var page: Int { min(6, max(0, kind == .photo ? photoPage : automationPage)) }
  private func setPage(_ value: Int) {
    if kind == .photo { photoPage = value } else { automationPage = value }
  }
  private var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Daily"
  }
  private var instruction: String {
    let keys = kind == .photo ? ["guideSettings", "guideAdd", "guidePhotos", "guideImage", "guideAddPhoto", "guideHome", "guideSelect"] :
      ["guideAutomation", "guidePlus", "guideApp", "guideChooseApp", "guideOpened", "guideImmediate", "guideChooseShortcut"]
    return t(keys[page])
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("\(page + 1) / 7").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            ProgressView(value: Double(page + 1), total: 7)
          }
          Text(instruction).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
          VStack(spacing: 20) {
            HStack {
              Image(systemName: kind == .photo ? "gearshape" : "square.stack.3d.up")
              Text(kind == .photo ? t("settingsApp") : t("open")).font(.subheadline.weight(.semibold))
              Spacer()
              Text(t("screenGuide")).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if kind == .photo { photoScreen } else { automationScreen }
          }
          .padding(20).frame(maxWidth: .infinity, minHeight: 270, alignment: .top)
          .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
          Text(t("guideTap")).font(.footnote).foregroundStyle(.secondary)
          Text(t("guideNote")).font(.caption).foregroundStyle(.secondary)
          if page == 6 { Text(t("guideEnd")).font(.callout) }
          if let error { Text(error).foregroundStyle(.red) }
          if kind == .automation {
            Button { DailyWallpaperLinks.open { if !$0 { error = t("openError") } } } label: {
              Label(t("open"), systemImage: "arrow.up.forward.app")
            }
          }
        }.frame(maxWidth: 520).padding(24).frame(maxWidth: .infinity)
      }
      .safeAreaInset(edge: .bottom) {
        HStack {
          Button { setPage(page - 1) } label: { Label(t("back"), systemImage: "chevron.left") }.disabled(page == 0)
          Spacer()
          Button(t(page == 6 ? "done" : "next")) { advance() }.buttonStyle(.borderedProminent)
        }.padding(20).background(.regularMaterial)
      }
      .navigationTitle(t(kind == .photo ? "photoGuide" : "automationGuide"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("done")) { dismiss() } } }
    }
    .environment(\.locale, DailyWallpaperText.locale)
  }
  private func advance() { if page < 6 { setPage(page + 1) } else { dismiss() } }
  private func target(_ title: String, symbol: String, trailing: String = "hand.tap") -> some View {
    Button(action: advance) {
      HStack(spacing: 12) {
        Image(systemName: symbol).frame(width: 24)
        Text(title).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 4)
        Image(systemName: trailing).accessibilityHidden(true)
      }.padding(14).frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2))
    }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
  }
  @ViewBuilder private var photoScreen: some View {
    switch page {
    case 0:
      Label(t("appearance"), systemImage: "sun.max").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
      target(t("wallpaperSettings"), symbol: "photo")
    case 1:
      WallpaperPreview(image: preview).frame(height: 170)
      target(t("addWallpaper"), symbol: "plus")
    case 2:
      target(t("photosWallpaper"), symbol: "photo")
    case 3:
      Button(action: advance) {
        WallpaperPreview(image: preview).frame(height: 220)
          .padding(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3))
      }.accessibilityLabel(t("choosePhoto"))
    case 4:
      HStack { Spacer(); target(t("saveWallpaper"), symbol: "plus").frame(maxWidth: 190) }
      WallpaperPreview(image: preview).frame(height: 200)
    case 5:
      target(t("customizeHomeScreen"), symbol: "house")
    default:
      WallpaperPreview(image: preview).frame(height: 220)
      target(t("photoReady"), symbol: "checkmark.circle")
    }
  }
  @ViewBuilder private var automationScreen: some View {
    switch page {
    case 0:
      Text(t("newAutomation")).foregroundStyle(.secondary)
      Spacer(minLength: 90)
      target(t("automation"), symbol: "bolt")
    case 1:
      HStack { Text(t("automation")).font(.headline); Spacer(); target("+", symbol: "plus").frame(maxWidth: 110) }
    case 2: target(t("app"), symbol: "app")
    case 3: target(appName, symbol: "calendar", trailing: "circle")
    case 4:
      Label(appName, systemImage: "calendar").frame(maxWidth: .infinity, alignment: .leading)
      target(t("opened"), symbol: "checkmark.circle.fill")
    case 5:
      target(t("immediate"), symbol: "bolt.fill")
      HStack { Spacer(); Text(t("next")).foregroundStyle(Color.accentColor) }
    default: target(DailyWallpaperStore.shortcutName, symbol: "calendar")
    }
  }
}

@available(iOS 16.0, *)
private struct DailyWallpaperRemovalView: View {
  let cleared: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var confirm = false
  @State private var message: String?
  private func t(_ key: String) -> String { DailyWallpaperText.value(key) }
  var body: some View {
    NavigationStack {
      Form {
        Section { Text(t("removeBody")); Text(t("removeHelper")) }
        Section {
          Button { DailyWallpaperLinks.open { if !$0 { message = t("openError") } } } label: {
            Label(t("open"), systemImage: "arrow.up.forward.app")
          }
          Button(t("clear"), role: .destructive) { confirm = true }
          if let message { Text(message).font(.footnote) }
        }
      }
      .navigationTitle(t("removeTitle")).navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("done")) { dismiss() } } }
      .alert(t("clear"), isPresented: $confirm) {
        Button(t("cancel"), role: .cancel) {}
        Button(t("clear"), role: .destructive) {
          do { try DailyWallpaperStore.clear(); cleared(); message = t("cleared") }
          catch { message = error.localizedDescription }
        }
      } message: { Text(t("clearConfirm")) }
    }.environment(\.locale, DailyWallpaperText.locale)
  }
}

@MainActor
private enum DailyWallpaperLinks {
  static func open(_ completion: @escaping @MainActor @Sendable (Bool) -> Void) {
    UIApplication.shared.open(URL(string: "shortcuts://")!, completionHandler: completion)
  }
  static func run(name: String = DailyWallpaperStore.shortcutName, _ completion: @escaping @MainActor @Sendable (Bool) -> Void) {
    guard name == DailyWallpaperStore.shortcutName else {
      var url = URLComponents()
      url.scheme = "shortcuts"
      url.host = "run-shortcut"
      url.queryItems = [URLQueryItem(name: "name", value: name)]
      UIApplication.shared.open(url.url!, completionHandler: completion)
      return
    }
    Task {
      await DailyWallpaperUpdateMonitor.requestNotificationPermission()
      do {
        let id = try await DailyWallpaperUpdateMonitor.begin(source: .app)
        var url = URLComponents()
        url.scheme = "shortcuts"
        url.host = "x-callback-url"
        url.path = "/run-shortcut"
        url.queryItems = [URLQueryItem(name: "name", value: name)] + ["success", "error", "cancel"].map {
          URLQueryItem(name: "x-\($0)", value: "daily-wallpaper://result/\($0)?id=\(id.uuidString)")
        }
        let opened = await UIApplication.shared.open(url.url!)
        if !opened { try await DailyWallpaperUpdateMonitor.finish(id: id, outcome: .failed, announce: true) }
        completion(opened)
      } catch { completion(false) }
    }
  }
}

private struct WallpaperShareFile: Identifiable {
  let id = UUID()
  let url: URL
}

private struct WallpaperFileShare: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
