#!/usr/bin/env python3
"""Build the web UI font from Noto Sans SC (SIL OFL).

The browser has no system fonts. This instantiates the variable face at
regular weight, keeps only the characters the game uses, and writes a
static TrueType that Godot loads from raw bytes.
"""

from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.subset import Subsetter, Options

ROOT = Path(__file__).resolve().parents[1]
SRC = Path("/tmp/fonts/NotoSansSC-VF.ttf")
OUT_TTF = ROOT / "art" / "fonts" / "ui_zh.ttf"
OUT_BYTES = ROOT / "art" / "fonts" / "ui_zh.bytes"
SCAN_EXT = {".gd", ".json", ".cfg", ".tscn", ".md", ".txt", ".gdshader"}
SKIP = {".godot", "build", "agent-tools", "uploads"}


def collect_text() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars.update("粮钱匠电民心回合终开罢关闭存读档科技树自动槽一二三写入读取空")
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in SCAN_EXT:
            continue
        if any(part in SKIP for part in path.parts):
            continue
        if path.name in {"OFL.txt", "OFL-NotoSans.txt", "ui_zh.ttf"}:
            continue
        chars.update(path.read_text("utf-8", errors="ignore"))
    return "".join(sorted(chars))


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing {SRC}; download Noto Sans SC VF first")
    text = collect_text()
    font = instantiateVariableFont(TTFont(SRC), {"wght": 400}, inplace=False)
    options = Options()
    options.glyph_names = True
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.legacy_cmap = True
    options.name_IDs = ["*"]
    options.layout_features = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.drop_tables = ["DSIG"]
    subsetter = Subsetter(options=options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    OUT_TTF.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT_TTF)
    data = OUT_TTF.read_bytes()
    OUT_BYTES.write_bytes(data)
    print(f"chars {len(text)} glyphs {font['maxp'].numGlyphs} bytes {len(data)}")


if __name__ == "__main__":
    main()
