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
ICON = ROOT / "IssueShot" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-512.png"
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


def rounded_arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int]) -> None:
    """ドラッグの向きを示す矢印（破線＋三角）"""
    x0, y0 = start
    x1, y1 = end
    dash, gap = 12 * SCALE, 9 * SCALE
    x = x0
    while x < x1 - 18 * SCALE:
        draw.line([(x, y0), (min(x + dash, x1 - 18 * SCALE), y1)], fill=EMERALD + (255,), width=3 * SCALE)
        x += dash + gap
    head = 11 * SCALE
    draw.polygon(
        [(x1, y1), (x1 - head * 1.4, y1 - head * 0.8), (x1 - head * 1.4, y1 + head * 0.8)],
        fill=EMERALD,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    image = background()
    draw = ImageDraw.Draw(image, "RGBA")
    s = SCALE

    # ヘッダー: アイコンとサービス名
    icon = Image.open(ICON).convert("RGBA").resize((72 * s, 72 * s), Image.LANCZOS)
    image.paste(icon, (48 * s, 36 * s), icon)
    draw.text((136 * s, 44 * s), "Revvy", font=font(40 * s, bold=True), fill=INK)
    draw.text((138 * s, 92 * s), "撮って、書き込んで、そのまま共有。", font=font(15 * s), fill=MUTED)
    draw.text((138 * s, 114 * s), "Capture, annotate, share.", font=font(13 * s), fill=MUTED)

    # コンセプトの 3 ステップ
    steps = [
        ("1", "撮る", "どのアプリの上からでも"),
        ("2", "書き込む", "枠・矢印・文字・ルーラー"),
        ("3", "渡す", "GitHub Issue やリンクで"),
    ]
    for index, (number, title, detail) in enumerate(steps):
        x = 48 * s + index * 204 * s
        y = 158 * s
        draw.ellipse([(x, y), (x + 22 * s, y + 22 * s)], fill=EMERALD)
        draw.text((x + 8 * s, y + 3 * s), number, font=font(13 * s, bold=True), fill=(255, 255, 255))
        draw.text((x + 32 * s, y + 1 * s), title, font=font(16 * s, bold=True), fill=INK)
        draw.text((x + 32 * s, y + 24 * s), detail, font=font(12 * s), fill=MUTED)

    # ドラッグの案内（アイコンは Finder が dmg-settings.py の位置に置く）
    rounded_arrow(draw, (250 * s, 300 * s), (446 * s, 300 * s))
    draw.text((48 * s, 372 * s), "Revvy をアプリケーションフォルダへドラッグ", font=font(14 * s, bold=True), fill=INK)
    draw.text((48 * s, 394 * s), "Drag Revvy into Applications", font=font(12 * s), fill=MUTED)
    draw.text((466 * s, 394 * s), "macOS 15+ · MIT License", font=font(11 * s), fill=MUTED)

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
