#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DMG のインストール画面の背景を作る。

使い方: python3 scripts/make-dmg-background.py
出力  : assets/dmg/background.png（@1x）, background@2x.png, background.tiff（Finder 用）,
        VolumeIcon.icns（DMG のボリュームアイコン）

Finder はウインドウの左上を原点に背景を敷く。アイコンの置き場所は
scripts/dmg-settings.py の icon_locations と合わせること。
"""
from __future__ import annotations

import math
import pathlib
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "dmg"
ICON_1024 = ROOT / "IssueShot" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

WIDTH, HEIGHT = 700, 440
SCALE = 2  # Retina 用に 2 倍で描いてから縮小する

EMERALD = (16, 158, 120)
INK = (18, 38, 33)
MUTED = (96, 124, 116)

FONTS = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """日本語が出るフォントを順に試す。index は W3/W6 の使い分け。"""
    for path in FONTS:
        try:
            return ImageFont.truetype(path, size, index=1 if bold and path.endswith(".ttc") else 0)
        except OSError:
            continue
    return ImageFont.load_default()


def background() -> Image.Image:
    """左上からうっすら緑がかる、明るい紙のような面"""
    w, h = WIDTH * SCALE, HEIGHT * SCALE
    image = Image.new("RGB", (w, h), (252, 253, 252))
    pixels = image.load()
    for y in range(h):
        for x in range(0, w, 4):  # 4px ごとに計算して塗る（滑らかさは十分）
            distance = math.hypot(x / w, y / h) / 1.414
            tint = max(0.0, 0.16 - distance * 0.16)
            color = (
                int(252 - tint * 60),
                int(253 - tint * 12),
                int(252 - tint * 40),
            )
            for offset in range(4):
                if x + offset < w:
                    pixels[x + offset, y] = color
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    image = background()
    draw = ImageDraw.Draw(image, "RGBA")
    s = SCALE

    # Finder の実アイコンを主役にし、上部と下部に余白を残す。
    draw.rounded_rectangle((32*s, 26*s, 668*s, 410*s), radius=24*s,
                           fill=(255, 255, 255, 185), outline=(214, 230, 222, 255), width=s)
    draw.text((60*s, 48*s), "Revvy", font=font(34*s, bold=True), fill=INK)
    draw.text((62*s, 96*s), "Capture. Annotate. Share.", font=font(13*s), fill=MUTED)
    draw.rounded_rectangle((549*s, 54*s, 640*s, 80*s), radius=13*s, fill=(229, 241, 233))
    draw.text((565*s, 60*s), "FOR MAC", font=font(10*s, bold=True), fill=(39, 100, 77))
    draw.line((60*s, 130*s, 640*s, 130*s), fill=(222, 233, 226), width=s)

    # アイコンは焼き込まず、Finder のドラッグ可能な項目をこの位置に重ねる。
    # dmg-settings.py の icon_locations と同じ中心。ラベルは円の外に置く。
    icon_center_y, circle_radius = 236, 70
    for cx in (180, 520):
        draw.ellipse(((cx-circle_radius)*s, (icon_center_y-circle_radius)*s,
                      (cx+circle_radius)*s, (icon_center_y+circle_radius)*s),
                     fill=(237, 246, 239, 255))
    draw.line((293*s, 236*s, 405*s, 236*s), fill=EMERALD, width=3*s)
    draw.line((393*s, 225*s, 405*s, 236*s, 393*s, 247*s), fill=EMERALD, width=3*s)
    draw.text((350*s, 261*s), "DRAG TO INSTALL", anchor="mt", font=font(9*s, bold=True), fill=MUTED)

    draw.text((350*s, 361*s), "Revvy を Applications へドラッグ", anchor="mt", font=font(15*s, bold=True), fill=INK)
    draw.text((350*s, 386*s), "Drag to Applications to get started.", anchor="mt", font=font(11*s), fill=MUTED)

    retina = image
    normal = image.resize((WIDTH, HEIGHT), Image.LANCZOS)
    normal.save(OUT / "background.png")
    retina.save(OUT / "background@2x.png")
    # Finder に両方の解像度を渡すため 1 枚の TIFF にまとめる
    subprocess.run(
        ["tiffutil", "-cathidpicheck", str(OUT / "background.png"), str(OUT / "background@2x.png"),
         "-out", str(OUT / "background.tiff")],
        check=True, capture_output=True,
    )
    volume_icon()
    print(f"✅ {OUT / 'background.tiff'} ({WIDTH}x{HEIGHT} @1x/@2x)")
    print(f"✅ {OUT / 'VolumeIcon.icns'}")


def volume_icon() -> None:
    """DMG のボリュームアイコン。アプリのアイコンから作る。"""
    iconset = OUT / "VolumeIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    sizes = [16, 32, 128, 256, 512]
    source = Image.open(ICON_1024).convert("RGBA")
    for size in sizes:
        source.resize((size, size), Image.LANCZOS).save(iconset / f"icon_{size}x{size}.png")
        source.resize((size * 2, size * 2), Image.LANCZOS).save(iconset / f"icon_{size}x{size}@2x.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(OUT / "VolumeIcon.icns")],
                   check=True, capture_output=True)
    for file in iconset.iterdir():
        file.unlink()
    iconset.rmdir()


if __name__ == "__main__":
    main()
