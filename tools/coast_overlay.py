#!/usr/bin/env python3
"""Draw the hex coastline and great rivers over a Natural Earth shore.

The hex map uses the same Lambert conformal conic as generate_map
(25°N / 45°N, central meridian 112°E). Natural Earth land is projected
into that plane and then into the hex-pixel frame, so a matching coast
should sit on the orange hex shore.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import generate_map as gm
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "data" / "map" / "map_1040.json"
NE_PATH = Path("/tmp/ne/ne_50m_land.geojson")
FONT_PATH = ROOT / "art" / "fonts" / "ui_zh.ttf"
OUT_DOCS = ROOT / "docs" / "coast_overlay.png"
OUT_ART = Path("/opt/cursor/artifacts/coast_overlay.png")


HEX_SIZE = 18.0


def hex_px(q: float, r: float, margin: float, scale: float) -> tuple[float, float]:
    x = margin + HEX_SIZE * math.sqrt(3.0) * (q + r / 2.0) * scale
    y = margin + HEX_SIZE * 1.5 * r * scale
    return x, y


def main() -> None:
    if not NE_PATH.exists():
        raise SystemExit(f"missing {NE_PATH}")
    mp = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    layout = gm.Layout()
    lay = mp["layout"]
    layout.col_w = float(lay["col_w_km"])
    layout.row_h = float(lay["row_h_km"])
    layout.origin_x = float(lay["origin_x_km"])
    layout.origin_y = float(lay["origin_y_km"])
    legend = {v: k for k, v in mp["terrain_legend"].items()}
    owner_legend = mp["owner_legend"]

    margin = 28.0
    scale = 0.55
    # Continuous axial of the grid corners, plus a pad.
    corners = []
    for col, row in ((0, 0), (gm.W - 1, 0), (0, gm.H - 1), (gm.W - 1, gm.H - 1)):
        corners.append(gm.offset_to_axial(col, row))
    xs, ys = [], []
    for q, r in corners:
        x, y = hex_px(q, r, margin, scale)
        xs.append(x)
        ys.append(y)
    width = int(max(xs) - min(xs) + margin * 2 + 40)
    height = int(max(ys) - min(ys) + margin * 2 + 40)

    img = Image.new("RGB", (width, height), (214, 224, 214))
    draw = ImageDraw.Draw(img)
    both_land = both_sea = map_extra = map_miss = 0
    hexes = []
    for row, line in enumerate(mp["terrains"]):
        for col, ch in enumerate(line):
            q, r = gm.offset_to_axial(col, row)
            tid = legend[ch]
            owner = owner_legend[mp["owners"][row][col]]
            x, y = layout.axial_to_km(q, r)
            lon, lat = gm.lambert_inverse(x, y)
            land = tid not in ("sea", "lake")
            hexes.append((q, r, tid, owner, lon, lat, land))

    ne = json.loads(NE_PATH.read_text(encoding="utf-8"))
    # Point-in-polygon against the 50m land multipolygon is slow if done naively
    # per hex. Use the generator's own is_sea only for the fill; the NE rings
    # are drawn on top so the eye can compare shores.
    for q, r, tid, owner, lon, lat, land in hexes:
        px, py = hex_px(q, r, margin, scale)
        if land:
            if owner == "song":
                fill = (214, 168, 150)
            elif owner == "liao":
                fill = (156, 176, 204)
            elif owner == "xia":
                fill = (186, 160, 184)
            elif owner:
                fill = (176, 196, 176)
            else:
                fill = (196, 188, 160)
        elif tid == "lake":
            fill = (150, 186, 196)
        else:
            fill = (168, 196, 210)
        rad = HEX_SIZE * scale * 0.92
        draw.regular_polygon((px, py, rad), 6, rotation=30, fill=fill)

    def project_ring2(ring: list):
        pts = []
        for coord in ring:
            lon, lat = coord[0], coord[1]
            if not (86.0 <= lon <= 136.0 and 16.0 <= lat <= 49.5):
                if len(pts) >= 2:
                    yield pts
                pts = []
                continue
            x_km, y_km = gm.lambert(lon, lat)
            # Inverse of axial_to_km: x = origin_x + col_w * (q + r/2), y = origin_y - row_h * r
            r = (layout.origin_y - y_km) / layout.row_h
            q = (x_km - layout.origin_x) / layout.col_w - r / 2.0
            pts.append(hex_px(q, r, margin, scale))
        if len(pts) >= 2:
            yield pts

    for feat in ne["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        if geom["type"] not in ("Polygon", "MultiPolygon"):
            continue
        for poly in polys:
            for part_i, ring in enumerate(poly):
                # Skip tiny holes; the outer ring is the shore we want.
                if part_i > 0 and len(ring) < 12:
                    continue
                for pts in project_ring2(ring):
                    if len(pts) >= 2:
                        draw.line(pts, fill=(24, 42, 64), width=2)

    # Hex shore: a land hex touching sea.
    sea_set = {(q, r) for q, r, tid, owner, lon, lat, land in hexes if tid == "sea"}
    land_set = {(q, r) for q, r, tid, owner, lon, lat, land in hexes if land}
    for q, r, tid, owner, lon, lat, land in hexes:
        if not land:
            continue
        for dq, dr in gm.DIRS:
            if (q + dq, r + dr) in sea_set:
                px, py = hex_px(q + dq * 0.45, r + dr * 0.45, margin, scale)
                draw.ellipse((px - 1.6, py - 1.6, px + 1.6, py + 1.6), fill=(196, 92, 28))
                break

    great = []
    for entry in mp["rivers"]:
        q, r, mask, gmask = entry
        if gmask:
            great.append((q, r))
    for q, r in great:
        px, py = hex_px(q, r, margin, scale)
        draw.ellipse((px - 1.3, py - 1.3, px + 1.3, py + 1.3), fill=(20, 78, 120))

    font = ImageFont.truetype(str(FONT_PATH), 22) if FONT_PATH.exists() else None
    marks = [
        ("渤海", 119.6, 38.8),
        ("山东", 120.8, 36.6),
        ("长江口", 121.8, 31.4),
        ("海南", 109.7, 19.2),
        ("台湾", 121.0, 23.7),
        ("高丽", 127.0, 37.4),
        ("雷州", 110.0, 20.9),
    ]
    if font:
        for name, lon, lat in marks:
            x_km, y_km = gm.lambert(lon, lat)
            r = (layout.origin_y - y_km) / layout.row_h
            q = (x_km - layout.origin_x) / layout.col_w - r / 2.0
            px, py = hex_px(q, r, margin, scale)
            draw.text((px + 4, py - 12), name, fill=(40, 24, 16), font=font)

    # Compare hex centres to Natural Earth with a prepared raster mask.
    # Rebuild a coarse lon/lat grid from the same polygons via matplotlib-free
    # ray casts only for the labelled boxes, printed to stdout.
    def ne_land(lon: float, lat: float) -> bool:
        # Cached feature rings are tested with gm.in_poly. Islands included.
        return _ne_contains(lon, lat)

    _rings = []
    for feat in ne["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        if geom["type"] not in ("Polygon", "MultiPolygon"):
            continue
        for poly in polys:
            if not poly:
                continue
            ring = [(p[0], p[1]) for p in poly[0]]
            lons = [p[0] for p in ring]
            lats = [p[1] for p in ring]
            _rings.append((min(lons), max(lons), min(lats), max(lats), ring))

    def _ne_contains(lon: float, lat: float) -> bool:
        for minx, maxx, miny, maxy, ring in _rings:
            if lon < minx or lon > maxx or lat < miny or lat > maxy:
                continue
            if gm.in_poly(lon, lat, ring):
                return True
        return False

    boxes = {
        "bohai": (119.2, 120.6, 38.2, 39.4),
        "shandong": (119.5, 122.8, 36.2, 37.8),
        "delta": (120.6, 122.3, 30.6, 32.2),
        "hainan": (108.6, 111.1, 18.1, 20.2),
        "taiwan": (120.0, 122.1, 21.9, 25.4),
        "korea": (125.5, 129.2, 34.6, 41.5),
        "leizhou": (109.8, 110.5, 20.25, 21.4),
    }
    print("region mapLand/mapSea/neLand-on-mapSea/neSea-on-mapLand")
    for name, (x0, x1, y0, y1) in boxes.items():
        ml = ms = miss = extra = 0
        for q, r, tid, owner, lon, lat, land in hexes:
            if not (x0 <= lon <= x1 and y0 <= lat <= y1):
                continue
            real = _ne_contains(lon, lat)
            if land:
                ml += 1
                if not real:
                    extra += 1
            else:
                ms += 1
                if real and tid == "sea":
                    miss += 1
        print(f"  {name}: land {ml} sea {ms} missing {miss} extra {extra}")

    # Song shape sentinels.
    by_city = {c["id"]: c for c in json.loads((ROOT / "data" / "cities.json").read_text())["cities"]}
    want = {
        "youzhou": "liao",
        "yanzhou": "song",
        "yinzhou": "xia",
        "chengdu": "song",
        "guangzhou": "song",
        "xingqing": "xia",
        "xiongzhou": "song",
    }
    print("shape")
    for cid, fac in want.items():
        c = by_city[cid]
        q, r = int(c["q"]), int(c["r"])
        got = owner_legend[mp["owners"][r][q + (r - (r & 1)) // 2]] if False else None
        # owners are stored by offset row/col, not axial.
        col = q + (r - (r & 1)) // 2
        got = owner_legend[mp["owners"][r][col]]
        print(f"  {c['short']} {got} want {fac}")

    img.save(OUT_DOCS)
    OUT_ART.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_ART)
    print(f"wrote {OUT_DOCS} {img.size}")


if __name__ == "__main__":
    main()
