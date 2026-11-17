#!/usr/bin/env python3
"""Generate native Android launcher icons from the branded square PNG."""
from __future__ import annotations

import argparse
import re
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image

DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def parse_color(value: str) -> tuple[int, int, int]:
    value = value.removeprefix("#")
    if len(value) != 6:
        raise ValueError("Background color must be #RRGGBB.")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def make_transparent_logo(source: Image.Image, background: tuple[int, int, int]) -> Image.Image:
    rgba = source.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, old_alpha = pixels[x, y]
            delta = max(abs(red - background[0]), abs(green - background[1]), abs(blue - background[2]))
            alpha = 0 if delta <= 12 else min(255, int((delta - 12) * 255 / 208))
            pixels[x, y] = (255, 255, 255, min(old_alpha, alpha))
    return rgba


def write_colors(path: Path, color: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        tree = ET.parse(path)
        root = tree.getroot()
    else:
        root = ET.Element("resources")
        tree = ET.ElementTree(root)
    node = root.find("./color[@name='ic_launcher_background']")
    if node is None:
        node = ET.SubElement(root, "color", {"name": "ic_launcher_background"})
    node.text = color.upper()
    ET.indent(tree, space="    ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--logo", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--background", required=True)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    logo_path = root / args.logo
    android = root / "android/app/src/main"
    manifest = android / "AndroidManifest.xml"
    if not logo_path.is_file():
        raise SystemExit(f"Launcher logo not found: {logo_path}")
    if not manifest.is_file():
        raise SystemExit(f"Android manifest not found: {manifest}")

    background = parse_color(args.background)
    source = Image.open(logo_path).convert("RGBA")
    if source.width != source.height:
        raise SystemExit(f"Launcher logo must be square; got {source.width}x{source.height}")

    # Legacy launcher icons retain the full branded background and wordmark.
    for folder, size in DENSITIES.items():
        destination = android / "res" / folder / "ic_launcher.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        source.resize((size, size), Image.Resampling.LANCZOS).save(destination, format="PNG")

    # Adaptive icons use a transparent white mark over the brand-color background.
    transparent_logo = make_transparent_logo(source, background)
    for folder, size in FOREGROUND_SIZES.items():
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        mark = transparent_logo.resize((int(size * 0.72), int(size * 0.72)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
        destination = android / "res" / folder / "ic_launcher_foreground.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(destination, format="PNG")

    adaptive = android / "res/mipmap-anydpi-v26/ic_launcher.xml"
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    write_colors(android / "res/values/colors.xml", args.background)

    manifest_text = manifest.read_text(encoding="utf-8")
    updated, count = re.subn(r'android:label="[^"]*"', f'android:label="{args.label}"', manifest_text, count=1)
    if count != 1:
        raise SystemExit("Could not find android:label in AndroidManifest.xml")
    manifest.write_text(updated, encoding="utf-8")
    print(f"Generated Android launcher icons and set app label to {args.label!r}.")


if __name__ == "__main__":
    main()
