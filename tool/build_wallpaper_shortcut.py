#!/usr/bin/env python3
"""Build and Apple-sign wallpaper update/setup shortcuts; never execute them."""

import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "com.littlebit0.daily"
TEAM = "A6Y73X2ZLS"
OUTPUT = ROOT / "ios/Runner/Resources/DailyCalendar Wallpaper.shortcut"
SETUP_OUTPUT = ROOT / "ios/Runner/Resources/DailyCalendar Wallpaper Setup.shortcut"


def identifier(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"daily-wallpaper:{name}")).upper()


def output(name, title):
    return {
        "Value": {"Type": "ActionOutput", "OutputUUID": identifier(name), "OutputName": title},
        "WFSerializationType": "WFTextTokenAttachment",
    }


def text_output(name, title):
    # String AppIntent parameters use a token string, not a file attachment.
    # Matches the working Signal action saved by the iOS Shortcuts editor.
    return {
        "Value": {"string": "\ufffc", "attachmentsByRange": {
            "{0, 1}": output(name, title)["Value"],
        }},
        "WFSerializationType": "WFTextTokenString",
    }


def action(kind, **parameters):
    return {"WFWorkflowActionIdentifier": kind, "WFWorkflowActionParameters": parameters}


def intent(kind, name, **parameters):
    # Descriptor format matches Daily's exported, working Signal shortcut.
    return action(f"{BUNDLE}.{kind}", UUID=identifier(name), AppIntentDescriptor={
        "TeamIdentifier": TEAM, "BundleIdentifier": BUNDLE,
        "Name": "Daily", "AppIntentIdentifier": kind,
    }, **parameters)


def condition(name, source):
    # Boolean "is true", matching the iOS editor's saved condition. A bare
    # attachment leaves the input blank; 100 means "has any value", not true.
    return action("is.workflow.actions.conditional", WFControlFlowMode=0,
                  GroupingIdentifier=identifier(name), WFCondition=4,
                  WFInput={"Type": "Variable", "Variable": source})


def end(name):
    return action("is.workflow.actions.conditional", WFControlFlowMode=2,
                  GroupingIdentifier=identifier(name))


def workflow():
    # A second guard catches OFF/reset while image generation is in flight.
    actions = [
        intent("DailyWallpaperEnabledIntent", "enabled"),
        condition("enabled-if", output("enabled", "Enabled")),
        intent("BeginDailyWallpaperUpdateIntent", "begin"),
        intent("GenerateDailyWallpaperIntent", "image", updateID=text_output("begin", "Update ID")),
        intent("DailyWallpaperEnabledIntent", "still-enabled"),
        condition("still-enabled-if", output("still-enabled", "Enabled")),
        action("is.workflow.actions.wallpaper.set",
               WFInput=output("image", "Calendar wallpaper"),
               WFWallpaperLocation=["Lock Screen"], WFWallpaperShowPreview=False,
               WFWallpaperPerspectiveZoom=False, WFWallpaperSmartCrop=False,
               WFWallpaperLegibilityBlur=False),
        intent("CompleteDailyWallpaperUpdateIntent", "complete", updateID=text_output("begin", "Update ID")),
        end("still-enabled-if"), end("enabled-if"),
    ]
    return {
        "WFWorkflowName": "DailyCalendar Wallpaper",
        "WFWorkflowClientVersion": "4711", "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983,
                           "WFWorkflowIconGlyphNumber": 59845},
        "WFWorkflowActions": actions,
        "WFWorkflowImportQuestions": [{
            "ActionIndex": 6, "Category": "Parameter", "ParameterKey": "WFSelectedPoster",
            "Text": "Choose the photo Lock Screen to update / 업데이트할 사진 잠금화면 선택",
        }],
        "WFWorkflowInputContentItemClasses": [], "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowHasOutputFallback": False, "WFWorkflowHasShortcutInputVariables": False,
        "WFWorkflowTypes": ["WFWorkflowTypeShowInSearch"], "WFQuickActionSurfaces": [],
    }


def setup_workflow():
    # A separate helper leaves existing automation quiet and its name unchanged.
    document = workflow()
    document["WFWorkflowName"] = SETUP_OUTPUT.stem
    document["WFWorkflowImportQuestions"] = []
    document["WFWorkflowActions"] = [
        intent("DailyWallpaperSetupIntent", "setup-choice"),
        condition("test-if", output("setup-choice", "Run test")),
        action("is.workflow.actions.runworkflow",
               WFWorkflow={"workflowName": OUTPUT.stem, "isSelf": False},
               WFWorkflowName=OUTPUT.stem),
        end("test-if"),
    ]
    return document


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unsigned", type=Path, help="Write inspectable plist without signing")
    parser.add_argument("--setup", action="store_true", help="With --unsigned, export the setup helper")
    args = parser.parse_args()
    if args.unsigned:
        document = setup_workflow() if args.setup else workflow()
        args.unsigned.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_BINARY, sort_keys=True))
        return
    if args.setup:
        parser.error("--setup requires --unsigned; signing builds both shortcuts")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="daily-wallpaper-") as temporary:
        signed_outputs = []
        for destination, document in [(OUTPUT, workflow()), (SETUP_OUTPUT, setup_workflow())]:
            source = Path(temporary) / destination.name
            signed = Path(temporary) / (destination.stem + "-signed.shortcut")
            source.write_bytes(plistlib.dumps(document, fmt=plistlib.FMT_BINARY, sort_keys=True))
            subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", str(source),
                            "--output", str(signed)], check=True)
            if not signed.read_bytes().startswith(b"AEA1"):
                raise ValueError("Signing did not produce an Apple signed shortcut")
            signed_outputs.append((signed, destination))
        # Keep existing resources if either signing request fails.
        for signed, destination in signed_outputs:
            destination.write_bytes(signed.read_bytes())
            print(destination)


if __name__ == "__main__":
    main()
