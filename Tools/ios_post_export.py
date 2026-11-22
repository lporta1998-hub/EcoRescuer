#!/usr/bin/env python3
"""Run after every iOS export from Godot, before building in Xcode:

    python3 Tools/ios_post_export.py            # patches build/ios
    python3 Tools/ios_post_export.py <xcode-project-dir>

Godot's exported launch screen is a storyboard with an image. Devices that
once ran a build with Godot's logo in it kept showing that logo at launch,
even after the image was replaced, the app deleted and the phone restarted.
This switches the app to the storyboard-free launch screen iOS also supports
(Info.plist `UILaunchScreen`): the Trash Patrol logo on black, the same as
Godot's boot splash (project.godot) and loading overlay (the storyboard,
which stays in the bundle for that), and the main menu fades in from black.

Safe to run more than once.
"""
import json
import os
import re
import shutil
import sys

PROJECT_NAME = "EcoRescuer"  # the exported Xcode project folder (not the game title)
BACKGROUND = (0.0, 0.0, 0.0)  # application/boot_splash/bg_color
LOGO = "Misc/AppIcon/launch_logo.png"  # application/boot_splash/image


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "build", "ios")
    app_dir = os.path.join(root, PROJECT_NAME)
    plist = os.path.join(app_dir, PROJECT_NAME + "-Info.plist")
    pbxproj = os.path.join(root, PROJECT_NAME + ".xcodeproj", "project.pbxproj")
    for path in (plist, pbxproj):
        if not os.path.exists(path):
            sys.exit("Not found: %s (export the iOS project from Godot first)" % path)

    # 1. Info.plist: storyboard launch screen -> background color + logo.
    text = open(plist, encoding="utf-8").read()
    text = re.sub(r"\s*<key>UILaunchStoryboardName</key>\s*<string>[^<]*</string>", "", text)
    text = re.sub(r"\s*<key>UILaunchScreen</key>\s*<dict>.*?</dict>", "", text, flags=re.S)
    launch = ("\t<key>UILaunchScreen</key>\n\t<dict>\n"
              "\t\t<key>UIColorName</key>\n\t\t<string>LaunchBackground</string>\n"
              "\t\t<key>UIImageName</key>\n\t\t<string>LaunchLogo</string>\n\t</dict>\n")
    text = text.replace("</dict>\n</plist>", launch + "</dict>\n</plist>", 1)
    open(plist, "w", encoding="utf-8").write(text)

    # The logo, at the same pixel size Godot draws it (same file for 2x and 3x).
    imageset = os.path.join(app_dir, "Images.xcassets", "LaunchLogo.imageset")
    os.makedirs(imageset, exist_ok=True)
    shutil.copyfile(os.path.join(here, "..", LOGO), os.path.join(imageset, "logo.png"))
    with open(os.path.join(imageset, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({
            "images": [{"idiom": "universal", "scale": s, "filename": "logo.png"} for s in ("2x", "3x")],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)

    # 2. The background color, as a color asset in the app's asset catalog.
    colorset = os.path.join(app_dir, "Images.xcassets", "LaunchBackground.colorset")
    os.makedirs(colorset, exist_ok=True)
    r, g, b = BACKGROUND
    with open(os.path.join(colorset, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({
            "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
                "red": "%.4f" % r, "green": "%.4f" % g, "blue": "%.4f" % b, "alpha": "1.000"}}}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)

    print("Launch screen patched: Trash Patrol logo on black (%s)" % root)


if __name__ == "__main__":
    main()
