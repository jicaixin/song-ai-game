#!/usr/bin/env python3
"""Drive the HTML5 build: new game, move or attack, end turn, save, continue."""

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

OUT = Path("/opt/cursor/artifacts")
OUT.mkdir(parents=True, exist_ok=True)
URL = "http://127.0.0.1:8734/?debug=1"


def snap(page, name: str) -> None:
    path = OUT / f"{name}.png"
    page.screenshot(path=str(path))
    print("shot", path)


def song(page):
    return page.evaluate("() => window.__song || null")


def wait_song(page, pred, timeout=30):
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
    # A same-frame right-click from Playwright never reaches Godot's input flush.
    # Move, let a frame land, then press and release.
    if button == "right":
        page.mouse.move(px, py)
        page.wait_for_timeout(280)
        page.mouse.down(button="right")
        page.wait_for_timeout(120)
        page.mouse.up(button="right")
    else:
        page.mouse.click(px, py, button=button)
    print(f"click {button} vp {x:.1f},{y:.1f} -> css {px:.1f},{py:.1f}")


def _pick_mover(page, state):
    # Prefer a Song unit that is not stuck in the opening ZOC ring.
    preferred = ["庆州厢军", "殿前司", "刘平部", "石元孙部"]
    units = {u["name"]: u for u in state["units"] if u["faction"] == "song" and u["hp"] > 0}
    for name in preferred:
        if name in units:
            return units[name]
    return next(u for u in state["units"] if u["faction"] == "song")


def _bring_on_screen(page, name: str):
    keys = {"a": False, "d": False, "w": False, "s": False}
    unit = None
    for _ in range(40):
        state = song(page)
        unit = next(u for u in state["units"] if u["name"] == name)
        hold = {"a": unit["sx"] < 80, "d": unit["sx"] > 420, "w": unit["sy"] < 48, "s": unit["sy"] > 260}
        if not any(hold.values()):
            break
        for key, down in hold.items():
            if down and not keys[key]:
                page.keyboard.down(key)
                keys[key] = True
            if not down and keys[key]:
                page.keyboard.up(key)
                keys[key] = False
        page.wait_for_timeout(120)
    for key, down in keys.items():
        if down:
            page.keyboard.up(key)
    page.wait_for_timeout(150)
    state = song(page)
    return next(u for u in state["units"] if u["name"] == name)


def boot(browser):
    # A CDP screenshot in this headless Chrome drops later right-clicks inside
    # Godot. Pages that must right-click stay screenshot-free until that click.
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    errors = []
    page.on("console", lambda msg: errors.append(f"{msg.type}: {msg.text}") if msg.type in ("error", "warning") else None)
    page.on("pageerror", lambda exc: errors.append(f"pageerror: {exc}"))
    page.goto(URL, wait_until="domcontentloaded")
    state = wait_song(page, lambda s: s.get("ready") and s.get("screen") == "title", 90)
    return page, state, errors


def start_game(page, state):
    btn = state["buttons"]["new_game"]
    click_vp(page, btn["x"] + btn["w"] / 2, btn["y"] + btn["h"] / 2)
    state = wait_song(page, lambda s: s.get("screen") == "game" and len(s.get("units") or []) >= 5, 20)
    page.wait_for_timeout(300)
    return song(page)


def main() -> int:
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            executable_path="/usr/local/bin/google-chrome",
            args=["--use-gl=angle", "--use-angle=swiftshader", "--disable-gpu-sandbox"],
        )
        page, state, err = boot(browser)
        errors.extend(err)
        print("title era", state.get("era"))
        snap(page, "01_title")
        page.close()

        page, state, err = boot(browser)
        errors.extend(err)
        state = start_game(page, state)
        snap(page, "02_map")
        print("era", state["era"], "advisor", state["advisor"][:40])
        garrison = next(u for u in state["units"] if u["name"] == "延州守军")
        click_vp(page, garrison["sx"], garrison["sy"])
        state = wait_song(page, lambda s, uid=garrison["uid"]: s.get("selected") == uid, 8)
        page.wait_for_timeout(200)
        state = song(page)
        snap(page, "03_selected")
        print("selected attacks", state.get("attacks"), "reachable", len(state.get("reachable") or []))
        page.close()

        page, state, err = boot(browser)
        errors.extend(err)
        state = start_game(page, state)
        garrison = next(u for u in state["units"] if u["name"] == "延州守军")
        click_vp(page, garrison["sx"], garrison["sy"])
        state = wait_song(page, lambda s, uid=garrison["uid"]: s.get("selected") == uid, 8)
        page.wait_for_timeout(200)
        state = song(page)
        print("attacks", state.get("attacks"), "reachable", len(state.get("reachable") or []))
        target = next(u for u in state["units"] if u["uid"] in (state.get("attacks") or []))
        print("target", target["name"], target["q"], target["r"])
        state = song(page)
        for _ in range(4):
            click_vp(page, target["sx"], target["sy"], "right")
            page.wait_for_timeout(350)
            state = song(page)
            print("preview", state.get("preview"), "clicks", state.get("clicks"))
            if state.get("preview"):
                break
        if not state.get("preview"):
            raise SystemExit("combat preview did not open")
        snap(page, "04_combat_preview")
        fight = state["buttons"]["fight"]
        click_vp(page, fight["x"] + fight["w"] / 2, fight["y"] + fight["h"] / 2)
        page.wait_for_timeout(400)
        state = song(page)
        snap(page, "05_after_combat")
        print("after combat", state.get("last_event"), "advisor", state.get("advisor", "")[:40])
        page.close()

        page, state, err = boot(browser)
        errors.extend(err)
        page.evaluate("() => localStorage.removeItem('songgame_slot_0')")
        state = start_game(page, state)
        mover = _pick_mover(page, state)
        mover = _bring_on_screen(page, mover["name"])
        print("mover", mover["name"], "at", round(mover["sx"], 1), round(mover["sy"], 1), "hex", mover["q"], mover["r"])
        box = page.locator("canvas").bounding_box()
        mpx = box["x"] + (mover["sx"] + 0.5) / 1280.0 * box["width"]
        mpy = box["y"] + (mover["sy"] + 0.5) / 720.0 * box["height"]
        page.mouse.move(mpx, mpy)
        state = wait_song(
            page,
            lambda s, q=mover["q"], r=mover["r"]: (s.get("hover") or {}).get("q") == q and (s.get("hover") or {}).get("r") == r,
            8,
        )
        print("mover hover", state.get("hover"))
        page.mouse.click(mpx, mpy)
        state = wait_song(page, lambda s, uid=mover["uid"]: s.get("selected") == uid, 8)
        mover = next(u for u in state["units"] if u["uid"] == mover["uid"])
        spots = [
            h for h in (state.get("reach_px") or [])
            if 48 <= h["sx"] <= 460 and 40 <= h["sy"] <= 270
        ]
        print("reachable", len(state.get("reachable") or []), "on screen", len(spots), "mp", mover["mp"])
        if not spots:
            raise SystemExit(mover["name"] + " has no on-screen reachable hex")
        dest = spots[0]
        print("move toward", dest["q"], dest["r"], "screen", dest["sx"], dest["sy"])
        state = song(page)
        for _ in range(3):
            click_vp(page, dest["sx"], dest["sy"], "right")
            page.wait_for_timeout(500)
            state = song(page)
            moved_try = next(u for u in state["units"] if u["uid"] == mover["uid"])
            print("move try", moved_try["q"], moved_try["r"], "event", state.get("last_event"), "clicks", state.get("clicks"))
            if [moved_try["q"], moved_try["r"]] != [mover["q"], mover["r"]]:
                break
        moved = next(u for u in state["units"] if u["uid"] == mover["uid"])
        print("moved", moved["name"], moved["q"], moved["r"], "from", mover["q"], mover["r"], "event", state.get("last_event"))
        if [moved["q"], moved["r"]] == [mover["q"], mover["r"]]:
            raise SystemExit(moved["name"] + " did not move")
        snap(page, "05b_after_move")
        end = state["buttons"]["end_turn"]
        click_vp(page, end["x"] + end["w"] / 2, end["y"] + end["h"] / 2)
        state = wait_song(page, lambda s: s.get("turn") == 2 and not s.get("locked"), 25)
        page.wait_for_timeout(300)
        state = song(page)
        snap(page, "06_next_turn")
        print("turn", state["turn"], state["era"], state["year"], state["month"], "advisor", state["advisor"][:48])
        stored = page.evaluate("() => localStorage.getItem('songgame_slot_0') || ''")
        print("save_len", len(stored))
        if len(stored) < 20:
            raise SystemExit("localStorage autosave missing")
        page.reload(wait_until="domcontentloaded")
        state = wait_song(page, lambda s: s.get("ready") and s.get("screen") == "title", 90)
        cont = state["buttons"]["continue"]
        print("continue", cont)
        if not cont.get("visible"):
            raise SystemExit("continue button hidden")
        click_vp(page, cont["x"] + cont["w"] / 2, cont["y"] + cont["h"] / 2)
        state = wait_song(page, lambda s: s.get("screen") == "game" and s.get("turn") == 2, 20)
        snap(page, "07_loaded")
        print("loaded turn", state["turn"], state["era"])
        page.close()
        browser.close()
    interesting = [e for e in errors if "SharedArrayBuffer" in e or "wasm" in e.lower() or e.startswith("pageerror")]
    print("errors", len(errors))
    for e in errors[:12]:
        print(" ", e[:240])
    if interesting:
        print("BLOCKERS", interesting)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("PLAYTEST FAILED", exc)
        sys.exit(1)
