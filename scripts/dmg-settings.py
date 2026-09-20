# -*- coding: utf-8 -*-
"""dmgbuild の設定。インストール画面の見た目をここで決める。

背景は assets/dmg/background.tiff（scripts/make-dmg-background.py で作る）。
アイコンの位置は背景の矢印と合わせること。
"""
import os
import pathlib

# dmgbuild は exec で読み込むので __file__ が無い。呼び出し側（scripts/dist.sh）が場所を渡す。
ROOT = pathlib.Path(os.environ.get("REVVY_ROOT", os.getcwd()))
APP = os.environ["REVVY_APP"]  # 署名済み Revvy.app の場所

# 取り込むもの
files = [APP]
symlinks = {"Applications": "/Applications"}
icon = str(ROOT / "assets" / "dmg" / "VolumeIcon.icns")

# ウインドウ
background = str(ROOT / "assets" / "dmg" / "background.tiff")
window_rect = ((240, 180), (700, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 12
icon_size = 128
icon_locations = {
    os.path.basename(APP): (160, 285),
    "Applications": (540, 285),
}

# 見せないもの（背景画像そのものなど）
hide_extension = [os.path.basename(APP)]
