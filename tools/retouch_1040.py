#!/usr/bin/env python3
"""Rewrite 1040 owners, the coast hexes, and the Yellow River mouth.

Reads the pinned Lambert layout. Does not refit it and does not move cities.
Coast hexes whose sea/land state disagrees with generate_map.is_sea are flipped:
sea becomes whatever classify() returns, land becomes sea unless it is a city or
a lake. Owners are then painted from faction_of. Rivers are rebuilt with the
same densify/greedy walk; sea hexes are skipped. Pass --write to replace
terrains, owners, owner_legend, rivers, and notes.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

import generate_map as gm

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "data" / "map" / "map_1040.json"
CITIES_PATH = ROOT / "data" / "cities.json"


def pinned_layout(mp: dict) -> gm.Layout:
    layout = gm.Layout()
    lay = mp["layout"]
    layout.col_w = float(lay["col_w_km"])
    layout.row_h = float(lay["row_h_km"])
    layout.origin_x = float(lay["origin_x_km"])
    layout.origin_y = float(lay["origin_y_km"])
    return layout


def load_terrain(mp: dict) -> dict[tuple[int, int], str]:
    legend = {v: k for k, v in mp["terrain_legend"].items()}
    terrain = {}
    for row, line in enumerate(mp["terrains"]):
        for col, ch in enumerate(line):
            q, r = gm.offset_to_axial(col, row)
            terrain[(q, r)] = legend[ch]
    return terrain


def retouch_coast(
    layout: gm.Layout,
    terrain: dict[tuple[int, int], str],
    cities: list[dict],
) -> list[tuple]:
    """Flip only the hexes whose sea test changed. Returns a log of edits."""
    occupied = {(int(c["q"]), int(c["r"])): c["id"] for c in cities}
    edits = []
    for key, tid in list(terrain.items()):
        x, y = layout.axial_to_km(*key)
        lon, lat = gm.lambert_inverse(x, y)
        sea = gm.is_sea(lon, lat)
        if tid == "lake":
            continue
        if sea and tid != "sea":
            if key in occupied:
                edits.append((key, round(lon, 2), round(lat, 2), tid, "kept-city"))
                continue
            terrain[key] = "sea"
            edits.append((key, round(lon, 2), round(lat, 2), tid, "sea"))
        elif not sea and tid == "sea":
            terrain[key] = gm.classify(lon, lat)
            edits.append((key, round(lon, 2), round(lat, 2), "sea", terrain[key]))
    return edits


def paint(layout: gm.Layout, terrain: dict[tuple[int, int], str]) -> dict[tuple[int, int], str]:
    owner = {}
    for (q, r), tid in terrain.items():
        x, y = layout.axial_to_km(q, r)
        lon, lat = gm.lambert_inverse(x, y)
        owner[(q, r)] = gm.faction_of(lon, lat, tid)
    return owner


def rebuild_rivers(layout: gm.Layout, terrain: dict[tuple[int, int], str]) -> dict[tuple[int, int], tuple[int, int]]:
    rivers: dict[tuple[int, int], int] = {}
    greats: dict[tuple[int, int], int] = {}

    def add_river(polyline: list[tuple[float, float]], great: bool) -> None:
        samples = [layout.latlon_to_axial(lon, lat) for lon, lat in gm.densify(polyline)]
        chain: list[tuple[int, int]] = []
        for a, b in zip(samples, samples[1:]):
            part = gm.greedy_path(a, b)
            if chain and part and chain[-1] == part[0]:
                chain.extend(part[1:])
            else:
                chain.extend(part)
        for a, b in zip(chain, chain[1:]):
            d = (b[0] - a[0], b[1] - a[1])
            if d not in gm.DIR_TO_I:
                continue
            i = gm.DIR_TO_I[d]
            j = (i + 3) % 6
            for hex_id, bit in ((a, i), (b, j)):
                if terrain.get(hex_id) == "sea":
                    continue
                rivers[hex_id] = rivers.get(hex_id, 0) | (1 << bit)
                if great:
                    greats[hex_id] = greats.get(hex_id, 0) | (1 << bit)

    add_river(gm.YELLOW, True)
    add_river(gm.YANGTZE, True)
    for line in (gm.HUAI, gm.HAN, gm.WEI, gm.FEN, gm.BIAN, gm.CANAL, gm.PEARL, gm.XIANG, gm.GAN):
        add_river(line, False)
    return {k: (rivers[k], greats.get(k, 0)) for k in rivers if rivers[k]}


def components(owner: dict, terrain: dict) -> dict[str, list[int]]:
    seen = set()
    out: dict[str, list[int]] = {}
    for start, fac in owner.items():
        if fac == "" or start in seen or terrain[start] in ("sea", "lake"):
            continue
        stack = [start]
        seen.add(start)
        n = 0
        while stack:
            cur = stack.pop()
            n += 1
            cq, cr = cur
            for dq, dr in gm.DIRS:
                nb = (cq + dq, cr + dr)
                if nb in seen or owner.get(nb) != fac:
                    continue
                if terrain.get(nb) in ("sea", "lake", None):
                    continue
                seen.add(nb)
                stack.append(nb)
        out.setdefault(fac, []).append(n)
    return out


def main() -> None:
    write = "--write" in sys.argv
    mp = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    cities = json.loads(CITIES_PATH.read_text(encoding="utf-8"))["cities"]
    layout = pinned_layout(mp)
    terrain = load_terrain(mp)
    edits = retouch_coast(layout, terrain, cities)
    print(f"coast edits {len(edits)}")
    for row in edits:
        print(" ", row)
    owner = paint(layout, terrain)

    worst = 0.0
    bad = []
    for city in cities:
        q, r = int(city["q"]), int(city["r"])
        x, y = layout.axial_to_km(q, r)
        lon, lat = gm.lambert_inverse(x, y)
        worst = max(worst, abs(lon - float(city["hex_lon"])), abs(lat - float(city["hex_lat"])))
        got = owner.get((q, r), "")
        if got != city["faction"]:
            bad.append((city["short"], city["faction"], got or "空", terrain.get((q, r)), round(lon, 2), round(lat, 2)))
    print(f"hex centre error vs cities.json: {worst:.4f} deg")
    if bad:
        print("CITY MISMATCHES")
        for row in bad:
            print(" ", row)
    else:
        print(f"cities {len(cities)} all match")

    counts = Counter((owner[k] or "none") for k in owner)
    print("owners", dict(counts))
    comps = components(owner, terrain)
    for fac, sizes in sorted(comps.items()):
        sizes = sorted(sizes, reverse=True)
        print(f"  component {fac}: {sizes[:6]}")

    # Border sentinels: the hex just north of a frontier city should be the other realm.
    watch = {
        "yanzhou": "xia",
        "qingyang": "xia",
        "xiongzhou": "liao",
        "daizhou": "liao",
        "fuzhou_fu": "liao",
        "qinzhou": "gusiluo",
        "yongzhou": "jiaozhi",
    }
    by_id = {c["id"]: c for c in cities}
    for cid, expect in watch.items():
        city = by_id[cid]
        q, r = int(city["q"]), int(city["r"])
        north = []
        for dq, dr in gm.DIRS:
            if dr >= 0 and not (dr == 0 and dq == 0):
                continue
            nb = (q + dq, r + dr)
            north.append((owner.get(nb) or "空", terrain.get(nb)))
        print(f"  north-of {city['short']}: {north} (want some {expect})")

    xlon, xlat = 89.19, 42.95
    xq, xr = layout.latlon_to_axial(xlon, xlat)
    occupied = {(int(c["q"]), int(c["r"])): c["id"] for c in cities}
    xx, xy = layout.axial_to_km(xq, xr)
    elon, elat = gm.lambert_inverse(xx, xy)
    print(
        f"xizhou axial {(xq, xr)} terrain {terrain.get((xq, xr))} owner {owner.get((xq, xr)) or '空'} "
        f"hex {elon:.2f},{elat:.2f} clash {occupied.get((xq, xr), '')}"
    )

    old = {(int(r[0]), int(r[1])): (int(r[2]), int(r[3])) for r in mp["rivers"]}
    new = rebuild_rivers(layout, terrain)
    only_old = sorted(set(old) - set(new))
    only_new = sorted(set(new) - set(old))
    changed = sorted(k for k in set(old) & set(new) if old[k] != new[k])
    print(f"rivers old {len(old)} new {len(new)} dropped {len(only_old)} added {len(only_new)} maskdiff {len(changed)}")
    mouth = []
    for key in only_old + only_new + changed:
        x, y = layout.axial_to_km(*key)
        lon, lat = gm.lambert_inverse(x, y)
        if lon >= 114.5:
            mouth.append((key, round(lon, 2), round(lat, 2), terrain.get(key), "old" if key in old and key not in new else "new" if key not in old else "diff"))
    print("river edits east of 114.5E:", mouth)

    chars = " .SXLGDKJU"
    # One character per hex, north at the top.
    print("owner grid (. empty S song X xia L liao G gusiluo D dali K goryeo J jiaozhi U uyghur)")
    for row in range(gm.H):
        chars_row = []
        for col in range(gm.W):
            q, r = gm.offset_to_axial(col, row)
            fac = owner[(q, r)]
            chars_row.append(gm.OWNER_CHAR.get(fac, "?"))
        print("".join(chars_row))

    if bad:
        raise SystemExit("refusing to write: city owners disagree with the polygons")
    if terrain.get((xq, xr)) in (None, "sea", "lake"):
        raise SystemExit("xizhou hex is not land")
    if (xq, xr) in occupied and occupied[(xq, xr)] != "xizhou":
        raise SystemExit("xizhou hex collides with " + occupied[(xq, xr)])
    if owner.get((xq, xr)) != "uyghur":
        raise SystemExit("xizhou hex is not uyghur")
    def box_count(lon0: float, lon1: float, lat0: float, lat1: float) -> tuple[int, int, int]:
        land = sea = song = 0
        for (q, r), tid in terrain.items():
            lon, lat = gm.lambert_inverse(*layout.axial_to_km(q, r))
            if not (lon0 <= lon <= lon1 and lat0 <= lat <= lat1):
                continue
            if tid == "sea":
                sea += 1
            elif tid != "lake":
                land += 1
                if owner[(q, r)] == "song":
                    song += 1
        return land, sea, song

    for name, box in (
        ("hainan", (108.5, 111.15, 18.05, 20.25)),
        ("leizhou", (109.7, 110.55, 20.2, 21.45)),
        ("shandong_tip", (122.15, 122.95, 37.15, 37.7)),
        ("delta", (120.8, 122.2, 30.7, 32.0)),
        ("taiwan", (120.0, 122.1, 21.9, 25.4)),
        ("korea", (124.4, 129.5, 34.3, 42.2)),
        ("bohai", (118.2, 121.2, 37.9, 40.2)),
    ):
        print(f"  {name} land/sea/song {box_count(*box)}")

    if not write:
        print("dry run (pass --write to update the json)")
        return

    legend = mp["terrain_legend"]
    terrain_rows = []
    for row in range(gm.H):
        chars_row = []
        for col in range(gm.W):
            q, r = gm.offset_to_axial(col, row)
            chars_row.append(legend[terrain[(q, r)]])
        terrain_rows.append("".join(chars_row))
    mp["terrains"] = terrain_rows

    rows = []
    for row in range(gm.H):
        oc = []
        for col in range(gm.W):
            q, r = gm.offset_to_axial(col, row)
            oc.append(gm.OWNER_CHAR[owner[(q, r)]])
        rows.append("".join(oc))
    mp["owners"] = rows
    mp["owner_legend"] = {v: k for k, v in gm.OWNER_CHAR.items()}
    mp["rivers"] = [[q, r, mask, great] for (q, r), (mask, great) in sorted(new.items())]
    mp["notes"] = (
        "1040 疆域近似，见 docs/song_1040_borders.md。"
        "兰伯特等角圆锥，标准纬线 25°N/45°N，中央经线 112°E。尖顶六边形，奇数行偏移。"
        "高山仍属所在政权。海、湖与台湾无主。海南岛为陆，属宋。"
        "黄河为 1048 商胡决口前的滨州入海故道。"
    )
    MAP_PATH.write_text(json.dumps(mp, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    col, row = gm.axial_to_offset(xq, xr)
    xizhou = {
        "id": "xizhou",
        "name": "西州高昌",
        "short": "高昌",
        "faction": "uyghur",
        "level": "zhou",
        "capital": True,
        "major": False,
        "circuit": "",
        "lon": xlon,
        "lat": xlat,
        "hex_lon": round(elon, 2),
        "hex_lat": round(elat, 2),
        "q": xq,
        "r": xr,
        "col": col,
        "row": row,
        "pop": 4,
        "morale": 60,
        "walls": 8,
        "output": {"food": 3, "money": 3, "craft": 1},
    }
    doc = json.loads(CITIES_PATH.read_text(encoding="utf-8"))
    if not any(c["id"] == "xizhou" for c in doc["cities"]):
        doc["cities"].append(xizhou)
        CITIES_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {MAP_PATH} and xizhou at {(xq, xr)}")


if __name__ == "__main__":
    main()
