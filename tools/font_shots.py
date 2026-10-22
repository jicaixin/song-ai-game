#!/usr/bin/env python3
"""Fresh-cache screenshots of Chinese UI, plus a pixel match against the font."""

import json
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from playwright.sync_api import sync_playwright

OUT = Path("/opt/cursor/artifacts")
OUT.mkdir(parents=True, exist_ok=True)
URL = "http://127.0.0.1:8734/?debug=1&fontcheck=1"
FONT = Path("/workspace/art/fonts/ui_zh.ttf")


def song(page):
    return page.evaluate("() => window.__song || null")


def wait_song(page, pred, timeout=40):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        last = song(page)
        if last and pred(last):
            return last
        page.wait_for_timeout(200)
    raise TimeoutError(json.dumps(last, ensure_ascii=False)[:500])


def click_vp(page, x, y, button="left"):
    box = page.locator("canvas").bounding_box()
    px = box["x"] + (x + 0.5) / 640.0 * box["width"]
    py = box["y"] + (y + 0.5) / 360.0 * box["height"]
    page.mouse.click(px, py, button=button)


def wheel_vp(page, x, y, delta):
    box = page.locator("canvas").bounding_box()
    px = box["x"] + (x + 0.5) / 640.0 * box["width"]
    py = box["y"] + (y + 0.5) / 360.0 * box["height"]
    page.mouse.move(px, py)
    page.mouse.wheel(0, delta)


def snap(page, name):
    path = OUT / f"{name}.png"
    page.screenshot(path=str(path))
    print("shot", path)
    return path


def render_ref(text: str, scale: int = 2) -> Image.Image:
    # The 640x360 view is integer-scaled to 1280x720, and canvas_items
    # stretch rasterizes the 12px face at that final size.
    font = ImageFont.truetype(str(FONT), 12 * scale)
    probe = Image.new("L", (8, 8), 255)
    draw = ImageDraw.Draw(probe)
    bbox = draw.textbbox((0, 0), text, font=font)
    w = max(1, bbox[2] - bbox[0] + 8)
    h = max(1, bbox[3] - bbox[1] + 8)
    img = Image.new("L", (w, h), 255)
    ImageDraw.Draw(img).text((4 - bbox[0], 4 - bbox[1]), text, font=font, fill=0)
    return img


def ink_mask(img: Image.Image, threshold=140):
    gray = img.convert("L")
    return gray.point(lambda p: 1 if p < threshold else 0)


def match_score(hay: Image.Image, needle: Image.Image) -> float:
    hay_m = ink_mask(hay)
    nee_m = ink_mask(needle)
    hw, hh = hay_m.size
    nw, nh = nee_m.size
    if nw > hw or nh > hh:
        return 0.0
    nee_px = list(nee_m.getdata())
    nee_ink = sum(nee_px) or 1
    best = 0.0
    step = 2
    hay_px = hay_m.load()
    for y in range(0, hh - nh + 1, step):
        for x in range(0, hw - nw + 1, step):
            hit = 0
            for ny in range(nh):
                for nx in range(nw):
                    if nee_px[ny * nw + nx] and hay_px[x + nx, y + ny]:
                        hit += 1
            best = max(best, hit / nee_ink)
            if best > 0.72:
                return best
    return best


def boot(browser):
    context = browser.new_context(viewport={"width": 1280, "height": 720})
    page = context.new_page()
    client = context.new_cdp_session(page)
    client.send("Network.setCacheDisabled", {"cacheDisabled": True})
    page.goto(URL, wait_until="domcontentloaded")
    state = wait_song(page, lambda s: s.get("ready") and s.get("screen") == "title", 90)
    return page, state


def main() -> int:
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            executable_path="/usr/local/bin/google-chrome",
            args=["--use-gl=angle", "--use-angle=swiftshader", "--disable-gpu-sandbox", "--disk-cache-size=1"],
        )
        page, state = boot(browser)
        print("title", state.get("era"))
        snap(page, "font_01_title")
        # Zoom is the canvas stretch here; also grab a tighter crop later.
        page.close()

        page, state = boot(browser)
        btn = state["buttons"]["new_game"]
        click_vp(page, btn["x"] + btn["w"] / 2, btn["y"] + btn["h"] / 2)
        state = wait_song(page, lambda s: s.get("screen") == "game" and len(s.get("units") or []) >= 5, 20)
        page.wait_for_timeout(300)
        # Hover a city-ish spot: 延州守军 is at the focus.
        garrison = next(u for u in song(page)["units"] if u["name"] == "延州守军")
        box = page.locator("canvas").bounding_box()
        hx = box["x"] + (garrison["sx"] + 0.5) / 640.0 * box["width"]
        hy = box["y"] + (garrison["sy"] + 0.5) / 360.0 * box["height"]
        page.mouse.move(hx, hy)
        page.wait_for_timeout(300)
        snap(page, "font_02_map_zoom1")
        wheel_vp(page, garrison["sx"], garrison["sy"], -120)
        page.wait_for_timeout(250)
        snap(page, "font_03_map_zoom2")
        wheel_vp(page, 320, 180, 120)
        wheel_vp(page, 320, 180, 120)
        page.wait_for_timeout(250)
        snap(page, "font_04_map_zoom05")
        # Back to 1x for panels. Two wheel-downs from 2x lands on 0.5; one wheel-up returns to 1.
        wheel_vp(page, 320, 180, -120)
        page.wait_for_timeout(200)
        tech = song(page)["buttons"]["tech"]
        click_vp(page, tech["x"] + tech["w"] / 2, tech["y"] + tech["h"] / 2)
        page.wait_for_timeout(250)
        snap(page, "font_05_tech")
        click_vp(page, song(page)["buttons"]["tech_close"]["x"] + 20, song(page)["buttons"]["tech_close"]["y"] + 10)
        page.wait_for_timeout(150)
        save = song(page)["buttons"]["save"]
        click_vp(page, save["x"] + save["w"] / 2, save["y"] + save["h"] / 2)
        page.wait_for_timeout(250)
        snap(page, "font_06_save")
        page.close()

        page, state = boot(browser)
        btn = state["buttons"]["new_game"]
        click_vp(page, btn["x"] + btn["w"] / 2, btn["y"] + btn["h"] / 2)
        wait_song(page, lambda s: s.get("screen") == "game" and len(s.get("units") or []) >= 5, 20)
        page.wait_for_timeout(250)
        state = song(page)
        garrison = next(u for u in state["units"] if u["name"] == "延州守军")
        click_vp(page, garrison["sx"], garrison["sy"])
        state = wait_song(page, lambda s, uid=garrison["uid"]: s.get("selected") == uid, 8)
        page.wait_for_timeout(200)
        state = song(page)
        target = next(u for u in state["units"] if u["uid"] in (state.get("attacks") or []))
        click_vp(page, target["sx"], target["sy"], "right")
        page.wait_for_timeout(400)
        state = song(page)
        print("preview", state.get("preview"), "advisor", (state.get("advisor") or "")[:24])
        if not state.get("preview"):
            click_vp(page, target["sx"], target["sy"], "right")
            page.wait_for_timeout(400)
            state = song(page)
            print("preview retry", state.get("preview"))
        if not state.get("preview"):
            raise SystemExit("combat preview did not open")
        snap(page, "font_07_combat")
        page.close()
        browser.close()

    checks = [
        ("font_01_title.png", "我带着AI穿越大宋", (360, 150, 940, 230), "font_crop_title.png"),
        ("font_01_title.png", "新游戏", (470, 330, 820, 430), "font_crop_newgame.png"),
        ("font_01_title.png", "宝元三年正月", (360, 210, 940, 280), "font_crop_era.png"),
        ("font_02_map_zoom1.png", "结束回合", (960, 530, 1280, 640), "font_crop_endturn.png"),
        ("font_02_map_zoom1.png", "东经", (980, 48, 1270, 220), "font_crop_tile.png"),
        ("font_05_tech.png", "科技树", (20, 40, 700, 140), "font_crop_tech.png"),
        ("font_06_save.png", "存档", (200, 120, 900, 280), "font_crop_save.png"),
        ("font_07_combat.png", "开战", (80, 380, 400, 500), "font_crop_fight.png"),
        ("font_07_combat.png", "守方", (80, 80, 900, 420), "font_crop_combat.png"),
    ]
    failed = []
    for name, text, box, crop_name in checks:
        shot = Image.open(OUT / name)
        band = shot.crop(box)
        ref = render_ref(text, 2)
        score = match_score(band, ref)
        print("match", text, round(score, 3), name)
        band.save(OUT / crop_name)
        if text == "我带着AI穿越大宋":
            ref.save(OUT / "font_ref_title.png")
        if score < 0.55:
            failed.append(f"{text} {score:.2f} in {name}")
    # City names are light glyphs with a dark outline, so the ink template
    # used above does not apply. Dump the pixels around 延州 instead.
    for name, box in (
        ("font_02_map_zoom1.png", (400, 200, 620, 360)),
        ("font_03_map_zoom2.png", (400, 200, 700, 420)),
        ("font_04_map_zoom05.png", (400, 220, 620, 360)),
        ("font_07_combat.png", (80, 560, 980, 700)),
    ):
        crop = Image.open(OUT / name).crop(box)
        crop.save(OUT / ("ascii_" + name))
        print("ASCII", name, box)
        _print_ascii(crop)
    if failed:
        raise SystemExit("glyphs do not match the font: " + "; ".join(failed))
    return 0


def _print_ascii(img: Image.Image, step: int = 2) -> None:
    gray = img.convert("L")
    w, h = gray.size
    px = gray.load()
    ramp = " .:-=+*#%@"
    for y in range(0, h, step):
        row = []
        for x in range(0, w, step):
            total = 0
            count = 0
            for dy in range(step):
                for dx in range(step):
                    if x + dx < w and y + dy < h:
                        total += px[x + dx, y + dy]
                        count += 1
            value = total / count
            row.append(ramp[min(len(ramp) - 1, int((255 - value) / 256 * len(ramp)))])
        print("".join(row))


if __name__ == "__main__":
    raise SystemExit(main())
