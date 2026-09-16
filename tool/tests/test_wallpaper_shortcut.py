"""Validate the generated workflow contract; these are NOT Shortcuts runtime tests."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("wallpaper", ROOT / "tool/build_wallpaper_shortcut.py")
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


class WallpaperShortcutTests(unittest.TestCase):
    def setUp(self):
        self.workflow = wallpaper.workflow()
        self.actions = self.workflow["WFWorkflowActions"]

    def test_plist_is_reproducible(self):
        encoded = plistlib.dumps(self.workflow, fmt=plistlib.FMT_BINARY)
        self.assertEqual(encoded, plistlib.dumps(wallpaper.workflow(), fmt=plistlib.FMT_BINARY))
        self.assertEqual(plistlib.loads(encoded), self.workflow)

    def test_only_daily_intents_and_guarded_lock_screen_action(self):
        identifiers = [a["WFWorkflowActionIdentifier"] for a in self.actions]
        self.assertEqual(identifiers, [
            "com.littlebit0.daily.DailyWallpaperEnabledIntent", "is.workflow.actions.conditional",
            "com.littlebit0.daily.BeginDailyWallpaperUpdateIntent",
            "com.littlebit0.daily.GenerateDailyWallpaperIntent", "com.littlebit0.daily.DailyWallpaperEnabledIntent",
            "is.workflow.actions.conditional", "is.workflow.actions.wallpaper.set",
            "com.littlebit0.daily.CompleteDailyWallpaperUpdateIntent",
            "is.workflow.actions.conditional", "is.workflow.actions.conditional",
        ])
        for enabled_index, condition_index, end_index in [(0, 1, 9), (4, 5, 8)]:
            enabled = self.actions[enabled_index]["WFWorkflowActionParameters"]
            condition = self.actions[condition_index]["WFWorkflowActionParameters"]
            end = self.actions[end_index]["WFWorkflowActionParameters"]
            self.assertEqual(condition["WFInput"]["Variable"]["Value"]["OutputUUID"], enabled["UUID"])
            self.assertEqual(condition["WFCondition"], 4)
            self.assertEqual(condition["WFControlFlowMode"], 0)
            self.assertEqual(end["WFControlFlowMode"], 2)
            self.assertEqual(condition["GroupingIdentifier"], end["GroupingIdentifier"])

    def test_wallpaper_receives_png_not_boolean_and_preserves_home_screen(self):
        params = self.actions[6]["WFWorkflowActionParameters"]
        self.assertEqual(params["WFInput"]["Value"]["OutputUUID"],
                         self.actions[3]["WFWorkflowActionParameters"]["UUID"])
        self.assertEqual(params["WFWallpaperLocation"], ["Lock Screen"])
        for key in ["WFWallpaperShowPreview", "WFWallpaperPerspectiveZoom",
                    "WFWallpaperSmartCrop", "WFWallpaperLegibilityBlur"]:
            self.assertIs(params[key], False)

    def test_import_question_does_not_embed_a_users_wallpaper_identifier(self):
        self.assertEqual(self.workflow["WFWorkflowImportQuestions"][0]["ActionIndex"], 6)
        self.assertEqual(self.workflow["WFWorkflowImportQuestions"][0]["ParameterKey"], "WFSelectedPoster")
        self.assertNotIn("WFSelectedPoster", self.actions[6]["WFWorkflowActionParameters"])

    def test_completion_matches_begin_and_occurs_only_after_wallpaper_action(self):
        begin_id = self.actions[2]["WFWorkflowActionParameters"]["UUID"]
        # Normalized from a real, working iOS Signal action's String parameter,
        # not derived from the generator. Bare WFTextTokenAttachment was ignored
        # at runtime, leaving updateID blank and prompting the user.
        fixture = json.loads((ROOT / "tool/tests/fixtures/ios26_string_action_output.json").read_text())
        for index in [3, 7]:
            token = copy.deepcopy(self.actions[index]["WFWorkflowActionParameters"]["updateID"])
            attachment = token["Value"]["attachmentsByRange"]["{0, 1}"]
            self.assertEqual(attachment["OutputUUID"], begin_id)
            attachment["OutputUUID"] = "STRING_OUTPUT"
            attachment["OutputName"] = "String result"
            self.assertEqual(token, fixture)
        self.assertEqual(self.actions[6]["WFWorkflowActionIdentifier"], "is.workflow.actions.wallpaper.set")
        self.assertEqual(self.actions[7]["WFWorkflowActionParameters"]["AppIntentDescriptor"]["AppIntentIdentifier"],
                         "CompleteDailyWallpaperUpdateIntent")

    def test_callbacks_are_consumed_by_native_scene_plugin_not_calendar_router(self):
        source = (ROOT / "ios/Runner/DailyWallpaper.swift").read_text()
        app = (ROOT / "ios/Runner/AppDelegate.swift").read_text()
        self.assertIn("FlutterSceneLifeCycleDelegate", source)
        self.assertIn("options connectionOptions: UIScene.ConnectionOptions?", source)
        self.assertIn("openURLContexts URLContexts:", source)
        self.assertIn("registrar.addSceneDelegate(bridge)", app)
        self.assertIn("super.userNotificationCenter(center, willPresent:", app)
        self.assertNotIn("removeAllPendingNotificationRequests", source)
        self.assertNotIn("removeAllDeliveredNotifications", source)
        self.assertIn("DailyWallpaperUpdateMonitor.clear()", source)
        view = (ROOT / "ios/Runner/DailyWallpaperSettingsView.swift").read_text()
        self.assertIn('url.host = "x-callback-url"', view)
        self.assertIn('["success", "error", "cancel"]', view)
        self.assertIn('t("updateNotVerified")', view)

    def test_signed_resource_is_bundled(self):
        self.assertTrue(wallpaper.OUTPUT.read_bytes().startswith(b"AEA1"))
        self.assertTrue(wallpaper.SETUP_OUTPUT.read_bytes().startswith(b"AEA1"))
        project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.assertIn("DailyCalendar Wallpaper.shortcut in Resources", project)
        self.assertIn("DailyCalendar Wallpaper Setup.shortcut in Resources", project)
        self.assertIn("DailyWallpaper.swift in Sources", project)

    def test_setup_runs_existing_update_only_after_positive_choice(self):
        helper = wallpaper.setup_workflow()
        encoded = plistlib.dumps(helper, fmt=plistlib.FMT_BINARY)
        self.assertEqual(encoded, plistlib.dumps(wallpaper.setup_workflow(), fmt=plistlib.FMT_BINARY))
        actions = helper["WFWorkflowActions"]
        self.assertEqual([a["WFWorkflowActionIdentifier"] for a in actions], [
            "com.littlebit0.daily.DailyWallpaperSetupIntent",
            "is.workflow.actions.conditional", "is.workflow.actions.runworkflow",
            "is.workflow.actions.conditional",
        ])
        params = [a["WFWorkflowActionParameters"] for a in actions]
        self.assertEqual(params[1]["WFCondition"], 4)
        self.assertEqual(params[1]["WFControlFlowMode"], 0)
        self.assertEqual(params[1]["WFInput"]["Variable"]["Value"]["OutputUUID"], params[0]["UUID"])
        self.assertEqual(params[1]["GroupingIdentifier"], params[3]["GroupingIdentifier"])
        self.assertEqual(params[3]["WFControlFlowMode"], 2)
        self.assertEqual(params[2]["WFWorkflow"], {"workflowName": wallpaper.OUTPUT.stem, "isSelf": False})
        self.assertNotEqual(helper["WFWorkflowName"], params[2]["WFWorkflowName"])
        self.assertEqual(helper["WFWorkflowImportQuestions"], [])
        self.assertNotIn("DailyWallpaperSetupIntent", str(self.workflow))

    def test_every_boolean_guard_matches_ios_editor_serialization(self):
        # iOS 26.5's user-edited first guard, observed read-only after the
        # original failed. Only group/output identifiers and label normalized.
        fixture = json.loads((ROOT / "tool/tests/fixtures/ios26_boolean_condition.json").read_text())
        for document in [self.workflow, wallpaper.setup_workflow()]:
            actions = document["WFWorkflowActions"]
            guards = [a for a in actions if a["WFWorkflowActionIdentifier"] ==
                      "is.workflow.actions.conditional" and
                      a["WFWorkflowActionParameters"]["WFControlFlowMode"] == 0]
            self.assertEqual(len(guards), 2 if document is self.workflow else 1)
            for guard in guards:
                params = copy.deepcopy(guard["WFWorkflowActionParameters"])
                params["GroupingIdentifier"] = "GROUP"
                variable = params["WFInput"]["Variable"]["Value"]
                variable["OutputUUID"] = "BOOLEAN_OUTPUT"
                variable["OutputName"] = "Boolean result"
                self.assertEqual(params, fixture)
                self.assertNotEqual(params["WFCondition"], 100,
                                    "OFF/declined is a value too; never use existence as consent")

    def test_native_helper_does_not_enable_consent_or_claim_installation(self):
        source = (ROOT / "ios/Runner/DailyWallpaper.swift").read_text()
        helper = source.split("struct DailyWallpaperSetupIntent: AppIntent {")[1].split(
            "struct GenerateDailyWallpaperIntent: AppIntent {")[0]
        self.assertIn("requestDisambiguation(", helper)
        self.assertIn('selected == t("showConnectionGuide")', helper)
        self.assertIn('guard selected == t("testSetup")', helper)
        self.assertIn('t("helperTestWarning")', helper)
        self.assertGreaterEqual(helper.count("settings.consentAccepted"), 2)
        self.assertNotIn("DailyWallpaperStore.save", helper)
        self.assertNotIn("DailyWallpaperStore.image", helper)
        self.assertNotIn("UserDefaults.standard.set", helper)
        self.assertIn("return .result(value: false)", helper)

    def test_setup_progress_is_separate_from_opt_in_and_reset(self):
        view = (ROOT / "ios/Runner/DailyWallpaperSettingsView.swift").read_text()
        source = (ROOT / "ios/Runner/DailyWallpaper.swift").read_text()
        self.assertIn("@State private var progress = DailyWallpaperStore.progress", view)
        self.assertIn("removeObject(forKey: guideStepKey)", source)
        self.assertIn("removeObject(forKey: progressKey)", source)
        for key in ["photoGuidePageKey", "automationGuidePageKey"]:
            self.assertIn(f"@AppStorage(DailyWallpaperStore.{key})", view)
            self.assertIn(f"removeObject(forKey: {key})", source)
        self.assertIn("DailyWallpaperLinks.run(name: DailyWallpaperStore.setupShortcutName)", view)
        self.assertIn('Section(t("optionalHelper"))', view)
        self.assertIn(".sheet(item: $file) { WallpaperFileShare(url: $0.url) }", view)
        self.assertNotIn("onDismiss: { showApplyCheck", view)
        guide = view.split("private struct WallpaperScreenGuide: View {")[1].split(
            "private struct DailyWallpaperRemovalView: View {")[0]
        for forbidden in ["saveProgress", "confirmPhoto", "confirmVisible", "DailyWallpaperStore.save", "App-prefs:"]:
            self.assertNotIn(forbidden, guide)

    def test_photo_save_is_explicit_add_only_not_an_automation_side_effect(self):
        view = (ROOT / "ios/Runner/DailyWallpaperSettingsView.swift").read_text()
        source = (ROOT / "ios/Runner/DailyWallpaper.swift").read_text()
        self.assertEqual(view.count("DailyWallpaperStore.savePhoto()"), 1)
        self.assertIn("DailyWallpaperStore.savePhoto()", view.split("private func primaryAction()")[1].split(
            "private func confirmStep()")[0])
        save = source.split("static func savePhoto()")[1].split("static var settings:")[0]
        self.assertIn("requestAuthorization(for: .addOnly)", save)
        self.assertIn("settings.enabled && settings.consentAccepted", save)
        self.assertIn("PHAssetCreationRequest.forAsset().addResource", save)
        self.assertNotIn("savePhoto()", source.split("struct GenerateDailyWallpaperIntent:")[1])
        info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
        self.assertIn("NSPhotoLibraryAddUsageDescription", info)
        self.assertNotIn("NSPhotoLibraryUsageDescription", info)

    def test_missing_internal_token_never_prompts_or_silently_succeeds(self):
        source = (ROOT / "ios/Runner/DailyWallpaper.swift").read_text()
        complete = source.split("struct CompleteDailyWallpaperUpdateIntent:")[1].split("final class DailyWallpaperBridge")[0]
        self.assertIn("var updateID: String?", complete)
        self.assertIn("throw DailyWallpaperError.invalidUpdateID", complete)
        self.assertIn("$0.source == .shortcut && $0.outcome == .waiting", complete)
        self.assertNotIn("requestValue", complete)
        self.assertNotIn("attempts.latest", complete)

    @unittest.skipUnless(os.environ.get("DAILY_WALLPAPER_BUILT_APP"), "Set DAILY_WALLPAPER_BUILT_APP after build")
    def test_compiled_intents_match_workflow_and_include_signed_file(self):
        app = Path(os.environ["DAILY_WALLPAPER_BUILT_APP"])
        metadata = json.loads((app / "Metadata.appintents/extract.actionsdata").read_text())["actions"]
        for index in [0, 2, 3, 4, 7]:
            descriptor = self.actions[index]["WFWorkflowActionParameters"]["AppIntentDescriptor"]
            intent = metadata[descriptor["AppIntentIdentifier"]]
            self.assertFalse(intent["openAppWhenRun"])
            self.assertTrue(intent["isDiscoverable"])
            self.assertEqual(intent["availabilityAnnotations"]["LNPlatformNameIOS"]["introducedVersion"], "16.0")
        self.assertEqual(metadata["GenerateDailyWallpaperIntent"]["authenticationPolicy"], 1)
        for name in ["GenerateDailyWallpaperIntent", "CompleteDailyWallpaperUpdateIntent"]:
            parameter = next(p for p in metadata[name]["parameters"] if p["name"] == "updateID")
            self.assertTrue(parameter["isOptional"], "Never prompt the user for an internal token")
            self.assertEqual(parameter["valueType"]["primitive"]["wrapper"]["typeIdentifier"], 0)
        self.assertEqual(metadata["DailyWallpaperEnabledIntent"]["authenticationPolicy"], 0)
        self.assertEqual(metadata["DailyWallpaperEnabledIntent"]["outputType"]["primitive"]["wrapper"]["typeIdentifier"], 1)
        self.assertEqual((app / wallpaper.OUTPUT.name).read_bytes(), wallpaper.OUTPUT.read_bytes())
        setup = metadata["DailyWallpaperSetupIntent"]
        self.assertFalse(setup["openAppWhenRun"])
        self.assertTrue(setup["isDiscoverable"])
        self.assertEqual(setup["authenticationPolicy"], 1)
        self.assertEqual(setup["outputType"]["primitive"]["wrapper"]["typeIdentifier"], 1)
        self.assertEqual(setup["availabilityAnnotations"]["LNPlatformNameIOS"]["introducedVersion"], "16.0")
        self.assertEqual((app / wallpaper.SETUP_OUTPUT.name).read_bytes(), wallpaper.SETUP_OUTPUT.read_bytes())


if __name__ == "__main__":
    unittest.main()
