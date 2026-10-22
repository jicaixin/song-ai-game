#!/usr/bin/env python3
"""Cache-busted WebGL screenshots of the 3D map, plus a short frame-time sample."""

import base64
import json
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

OUT = Path("/opt/cursor/artifacts")
OUT.mkdir(parents=True, exist_ok=True)
URL = "http://127.0.0.1:8734/?debug=1&terrain=1"


def song(page):
    return page.evaluate("() => window.__song || null")


def wait_song(page, pred, timeout=50):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        last = song(page)
        if last and pred(last):
            return last
        page.wait_for_timeout(200)
    raise TimeoutError(json.dumps(last, ensure_ascii=False)[:800])


def click_vp(page, x, y, button="left"):
    box = page.locator("canvas").bounding_box()
    px = box["x"] + (x + 0.5) / 1280.0 * box["width"]
    py = box["y"] + (y + 0.5) / 720.0 * box["height"]
    page.mouse.click(px, py, button=button)


def canvas_png(page, name):
    data = page.evaluate(
        """() => {
            const c = document.querySelector('canvas');
            if (!c) return '';
            try { return c.toDataURL('image/png'); } catch (e) { return ''; }
        }"""
    )
    path = OUT / f"{name}.png"
    if data and data.startswith("data:image"):
        raw = base64.b64decode(data.split(",", 1)[1])
        path.write_bytes(raw)
        print("canvas", name, len(raw))
    else:
        page.locator("canvas").screenshot(path=str(path))
        print("element", name, path.stat().st_size)
    return path


def focus(page, city, zoom, name=None):
    token = f"{city},{zoom},{time.time()}"
    page.evaluate("(t) => { window.__focusCity = t; }", token)
    page.wait_for_timeout(700)
    canvas_png(page, name or f"terrain_{city}_z{zoom}")


def sample_fps(page):
    stats = page.evaluate(
        """() => new Promise((resolve) => {
            let n = 0;
            let last = performance.now();
            const dts = [];
            function tick(now) {
                dts.push(now - last);
                last = now;
                n += 1;
                if (n < 90) requestAnimationFrame(tick);
                else {
                    dts.sort((a, b) => a - b);
                    const avg = dts.reduce((s, v) => s + v, 0) / dts.length;
                    resolve({
                        frames: dts.length,
                        avg_ms: avg,
                        p50_ms: dts[Math.floor(dts.length * 0.5)],
                        p95_ms: dts[Math.floor(dts.length * 0.95)],
                    });
                }
            }
            requestAnimationFrame(tick);
        })"""
    )
    print("fps", json.dumps(stats))
    (OUT / "terrain_fps.json").write_text(json.dumps(stats, indent=2))
    return stats


def main() -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            executable_path="/usr/local/bin/google-chrome",
            args=[
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--disable-gpu-sandbox",
                "--disk-cache-size=1",
            ],
        )
        context = browser.new_context(viewport={"width": 1280, "height": 720})
        page = context.new_page()
        page.on("console", lambda msg: print("console", msg.type, msg.text[:240]))
        client = context.new_cdp_session(page)
        client.send("Network.setCacheDisabled", {"cacheDisabled": True})
        page.goto(URL, wait_until="domcontentloaded")
        state = wait_song(page, lambda s: s.get("ready") and s.get("screen") == "title", 90)
        print("title", state.get("era"))
        page.wait_for_timeout(400)
        canvas_png(page, "terrain_00_title")
        btn = state["buttons"]["new_game"]
        click_vp(page, btn["x"] + btn["w"] / 2, btn["y"] + btn["h"] / 2)
        state = wait_song(page, lambda s: s.get("screen") == "game", 40)
        print("game", state.get("era"), "units", len(state.get("units") or []))
        page.wait_for_timeout(800)
        for city, zoom in [
            ("xingqing", 0),
            ("xingqing", 1),
            ("xingqing", 2),
            ("yanzhou", 0),
            ("yanzhou", 1),
            ("yanzhou", 2),
            ("kaifeng", 0),
            ("kaifeng", 1),
            ("kaifeng", 2),
            ("hangzhou", 0),
            ("hangzhou", 1),
            ("hangzhou", 2),
            ("yangzhou", 1),
            ("30:36", 1),
            ("29:42", 2),
            ("16:30", 2),
            ("12:23", 1),
        ]:
            focus(page, city, zoom)
        sample_fps(page)
        meta = song(page) or {}
        canvas = page.evaluate(
            """() => {
                const c = document.querySelector('canvas');
                return c ? {w: c.width, h: c.height, cw: c.clientWidth, ch: c.clientHeight, dpr: window.devicePixelRatio} : {};
            }"""
        )
        meta_out = {
            "span": meta.get("span"),
            "zoom": meta.get("zoom"),
            "draw_calls": meta.get("draw_calls"),
            "prims": meta.get("prims"),
            "tris": meta.get("tris"),
            "canvas": canvas,
        }
        print("meta", json.dumps(meta_out, ensure_ascii=False))
        (OUT / "terrain_meta.json").write_text(json.dumps(meta_out, indent=2))
        browser.close()
        browser = p.chromium.launch(
            headless=True,
            executable_path="/usr/local/bin/google-chrome",
            args=[
                "--use-gl=angle",
                "--use-angle=swiftshader",
                "--disable-gpu-sandbox",
                "--force-device-scale-factor=2",
                "--disk-cache-size=1",
            ],
        )
        context = browser.new_context(
            viewport={"width": 1280, "height": 720},
            device_scale_factor=2,
        )
        page = context.new_page()
        client = context.new_cdp_session(page)
        client.send("Network.setCacheDisabled", {"cacheDisabled": True})
        page.goto(URL, wait_until="domcontentloaded")
        state = wait_song(page, lambda s: s.get("ready") and s.get("screen") == "title", 90)
        page.wait_for_timeout(500)
        canvas_png(page, "text_hidpi_title")
        btn = state["buttons"]["new_game"]
        click_vp(page, btn["x"] + btn["w"] / 2, btn["y"] + btn["h"] / 2)
        wait_song(page, lambda s: s.get("screen") == "game", 40)
        page.wait_for_timeout(900)
        focus(page, "yanzhou", 1, "text_hidpi_map")
        hidpi = page.evaluate(
            """() => {
                const c = document.querySelector('canvas');
                if (!c) return {};
                return {w: c.width, h: c.height, cw: c.clientWidth, ch: c.clientHeight, dpr: window.devicePixelRatio};
            }"""
        )
        print("hidpi", json.dumps(hidpi))
        (OUT / "terrain_hidpi.json").write_text(json.dumps(hidpi, indent=2))
        browser.close()


if __name__ == "__main__":
    main()
