#!/usr/bin/env python3
"""Subset Fusion Pixel and convert it from CFF/OTF to TrueType.

The web export has no system fonts. The full CFF font was packed, but Chinese
still drew as hex boxes. A small TrueType subset is loaded from raw bytes so
the face does not depend on the editor import or on OS fallback.
"""

from pathlib import Path

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.subset import Subsetter, Options
from fontTools.ttLib import TTFont, newTable

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art" / "fonts" / "FusionPixel12-zh_hans.otf"
OUT_TTF = ROOT / "art" / "fonts" / "ui_zh.ttf"
OUT_BYTES = ROOT / "art" / "fonts" / "ui_zh.bytes"
SCAN_EXT = {".gd", ".json", ".cfg", ".tscn", ".md", ".txt"}
SKIP = {".godot", "build", "agent-tools", "uploads"}


def collect_text() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in SCAN_EXT:
            continue
        if any(part in SKIP for part in path.parts):
            continue
        if path.name in {"OFL.txt", "ui_zh.ttf"}:
            continue
        chars.update(path.read_text("utf-8", errors="ignore"))
    return "".join(sorted(chars))


def to_ttf(font: TTFont) -> None:
    glyph_order = font.getGlyphOrder()
    font["loca"] = newTable("loca")
    glyf = newTable("glyf")
    glyf.glyphOrder = glyph_order
    glyphs = {}
    source = font.getGlyphSet()
    for name in glyph_order:
        pen = TTGlyphPen(None)
        source[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        glyphs[name] = pen.glyph()
    glyf.glyphs = glyphs
    font["glyf"] = glyf
    del font["CFF "]
    glyf.compile(font)
    hmtx = font["hmtx"]
    for name, glyph in glyf.glyphs.items():
        if hasattr(glyph, "xMin"):
            hmtx[name] = (hmtx[name][0], glyph.xMin)
    maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    maxp.maxZones = 1
    maxp.maxTwilightPoints = 0
    maxp.maxStorage = 0
    maxp.maxFunctionDefs = 0
    maxp.maxInstructionDefs = 0
    maxp.maxStackElements = 0
    maxp.maxSizeOfInstructions = 0
    maxp.maxComponentElements = max(
        (len(g.components) for g in glyf.glyphs.values() if hasattr(g, "components")),
        default=0,
    )
    font["maxp"] = maxp
    post = font["post"]
    post.formatType = 3.0
    font.sfntVersion = "\000\001\000\000"


def main() -> None:
    text = collect_text()
    font = TTFont(SRC)
    options = Options()
    options.glyph_names = True
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.legacy_cmap = True
    options.symbol_cmap = True
    options.name_IDs = ["*"]
    options.layout_features = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    subsetter = Subsetter(options=options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    to_ttf(font)
    OUT_TTF.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT_TTF)
    data = OUT_TTF.read_bytes()
    OUT_BYTES.write_bytes(data)
    print(f"chars {len(text)} glyphs {font['maxp'].numGlyphs} bytes {len(data)}")


if __name__ == "__main__":
    main()
