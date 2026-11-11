"""Copia el arte de art/ al catálogo de Xcode (imagesets) y genera el AppIcon.

Uso: python3 tools/build_assets.py
"""
import json
import os
import shutil

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
ART = os.path.join(ROOT, "art")
XC = os.path.join(ROOT, "Tutifruti", "Assets.xcassets")


def imageset(name, src, folder):
    d = os.path.join(XC, folder, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    shutil.copy(src, os.path.join(d, f"{name}.png"))
    json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)


def folder(name):
    d = os.path.join(XC, name)
    os.makedirs(d, exist_ok=True)
    json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
              open(os.path.join(d, "Contents.json"), "w"), indent=2)


folder("Avatars")
for f in sorted(os.listdir(os.path.join(ART, "avatars"))):
    if f.endswith(".png"):
        imageset("avatar_" + f[:-4], os.path.join(ART, "avatars", f), "Avatars")

folder("Mascot")
for f in sorted(os.listdir(os.path.join(ART, "mascot"))):
    if f.endswith(".png"):
        imageset(f[:-4], os.path.join(ART, "mascot", f), "Mascot")

folder("Icons")
for f in sorted(os.listdir(os.path.join(ART, "icons"))):
    if f.endswith(".png"):
        imageset("icon_" + f[:-4], os.path.join(ART, "icons", f), "Icons")

folder("UI")
for f in sorted(os.listdir(os.path.join(ART, "ui"))):
    if f.endswith(".png"):
        imageset(f[:-4], os.path.join(ART, "ui", f), "UI")

icon = os.path.join(ART, "icon.png")
if os.path.exists(icon):
    d = os.path.join(XC, "AppIcon.appiconset")
    im = Image.open(icon).convert("RGB").resize((1024, 1024), Image.LANCZOS)  # sin alfa (App Store)
    im.save(os.path.join(d, "icon-1024.png"))
    json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)
    # versión del logo para usar dentro de la app
    imageset("app_logo", icon, "Mascot")

print("ok")
