#!/usr/bin/env python3
"""Placeholder pixel sprites. Final art is a later milestone."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UNITS = ROOT / "art" / "units"
FACES = ROOT / "art" / "advisor"
UNITS.mkdir(parents=True, exist_ok=True)
FACES.mkdir(parents=True, exist_ok=True)

SKIN = (224, 176, 144, 255)
OUT = (28, 20, 16, 255)


def blank(n=24):
    return Image.new("RGBA", (n, n), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
        im.putpixel((x, y), c)


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(im, xx, yy, c)


def infantry(robe, trim, weapon):
    im = blank()
    rect(im, 6, 18, 12, 3, trim)  # base
    rect(im, 9, 8, 6, 8, robe)
    rect(im, 10, 4, 4, 4, SKIN)
    rect(im, 10, 3, 4, 2, trim)
    rect(im, 8, 16, 2, 3, (60, 44, 32, 255))
    rect(im, 14, 16, 2, 3, (60, 44, 32, 255))
    if weapon == "spear":
        rect(im, 16, 2, 1, 16, (90, 70, 40, 255))
        rect(im, 15, 2, 3, 2, (200, 200, 210, 255))
    elif weapon == "bow":
        rect(im, 17, 6, 1, 8, (120, 80, 40, 255))
        rect(im, 18, 7, 1, 2, (120, 80, 40, 255))
        rect(im, 18, 11, 1, 2, (120, 80, 40, 255))
    elif weapon == "sword":
        rect(im, 16, 8, 1, 8, (190, 196, 204, 255))
    return im


def cavalry(robe, horse, trim):
    im = blank()
    rect(im, 4, 16, 16, 4, horse)
    rect(im, 18, 14, 4, 3, horse)
    rect(im, 3, 18, 2, 3, (50, 36, 24, 255))
    rect(im, 8, 18, 2, 3, (50, 36, 24, 255))
    rect(im, 14, 18, 2, 3, (50, 36, 24, 255))
    rect(im, 9, 9, 6, 6, robe)
    rect(im, 10, 5, 4, 4, SKIN)
    rect(im, 10, 4, 4, 2, trim)
    rect(im, 16, 6, 1, 8, (190, 196, 204, 255))
    return im


def save_unit(name, im):
    im.save(UNITS / f"{name}.png")


def face(mood):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 4, 45, 46), 8, fill=(168, 78, 64, 255))
    d.rounded_rectangle((6, 8, 41, 42), 6, fill=(196, 106, 88, 255))
    if mood == "off":
        d.rounded_rectangle((10, 16, 37, 38), 3, fill=(12, 14, 16, 255))
        return im
    d.rounded_rectangle((10, 16, 37, 38), 3, fill=(16, 24, 32, 255))
    eye = (232, 236, 224, 255)
    if mood == "sleepy":
        rect(im, 16, 24, 5, 1, eye)
        rect(im, 27, 24, 5, 1, eye)
    elif mood == "shock":
        rect(im, 15, 22, 4, 4, eye)
        rect(im, 28, 22, 4, 4, eye)
    elif mood == "think":
        rect(im, 15, 23, 4, 2, eye)
        rect(im, 29, 22, 3, 2, eye)
    else:
        rect(im, 16, 23, 4, 2, eye)
        rect(im, 28, 23, 4, 2, eye)
    blush = (196, 112, 112, 255)
    if mood != "serious":
        rect(im, 13, 27, 3, 2, blush)
        rect(im, 32, 27, 3, 2, blush)
    mouth = (240, 196, 176, 255)
    if mood in ("smug", "moved"):
        rect(im, 20, 31, 8, 1, mouth)
        rect(im, 19, 30, 2, 1, mouth)
        rect(im, 27, 30, 2, 1, mouth)
    elif mood == "disgust":
        rect(im, 20, 32, 8, 1, mouth)
        rect(im, 26, 31, 3, 1, mouth)
    elif mood == "shock":
        rect(im, 22, 30, 4, 3, mouth)
    elif mood == "awkward":
        rect(im, 21, 31, 5, 1, mouth)
        rect(im, 26, 32, 2, 1, mouth)
    elif mood == "serious":
        rect(im, 20, 31, 8, 1, mouth)
    elif mood == "sleepy":
        rect(im, 22, 32, 4, 1, mouth)
    else:
        rect(im, 21, 31, 6, 1, mouth)
    # tiny antenna / hinge so it reads as a device, not just a bun
    rect(im, 23, 2, 2, 4, (60, 36, 32, 255))
    return im


def icon():
    im = Image.new("RGBA", (128, 128), (28, 22, 18, 255))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((24, 28, 104, 108), 16, fill=(168, 78, 64, 255))
    d.rounded_rectangle((36, 44, 92, 96), 8, fill=(16, 24, 32, 255))
    d.rectangle((52, 62, 60, 66), fill=(232, 236, 224, 255))
    d.rectangle((70, 62, 78, 66), fill=(232, 236, 224, 255))
    d.rectangle((58, 78, 72, 80), fill=(240, 196, 176, 255))
    im.save(ROOT / "icon.png")
    im.resize((32, 32), Image.Resampling.NEAREST).save(ROOT / "icon_32.png")


def main():
    song = (142, 46, 42, 255)
    song_trim = (90, 24, 22, 255)
    xia_robe = (214, 206, 190, 255)
    xia_trim = (36, 32, 28, 255)
    xia_horse = (72, 56, 48, 255)
    liao = (48, 64, 96, 255)
    liao_trim = (198, 162, 74, 255)
    save_unit("song_xiangjun", infantry((120, 96, 72, 255), song_trim, "sword"))
    save_unit("song_spear", infantry(song, song_trim, "spear"))
    save_unit("song_archer", infantry((90, 58, 48, 255), song_trim, "bow"))
    save_unit("xia_tieyaozi", cavalry(xia_robe, (40, 36, 34, 255), xia_trim))
    save_unit("xia_buba", infantry((92, 78, 60, 255), xia_trim, "sword"))
    save_unit("xia_tribal", cavalry((150, 110, 70, 255), xia_horse, xia_trim))
    save_unit("liao_pishi", cavalry(liao, (36, 40, 48, 255), liao_trim))
    for mood in ("normal", "smug", "disgust", "shock", "sleepy", "serious", "think", "awkward", "moved", "off"):
        face(mood).save(FACES / f"{mood}.png")
    icon()
    print("art ok", len(list(UNITS.glob('*.png'))), "units")


if __name__ == "__main__":
    main()
