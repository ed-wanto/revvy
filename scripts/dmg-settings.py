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
# 440pt の背景にタイトルバーの 32pt を加える。
window_rect = ((240, 180), (700, 472))
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
icon_size = 112
icon_locations = {
    os.path.basename(APP): (180, 236),
    "Applications": (520, 236),
}

# 署名済みアプリに SetFile を実行すると FinderInfo が付き、厳格な署名検証に失敗する。
# .app の拡張子は Finder 標準の表示に任せる。
