#!/usr/bin/env python3
"""First-pass 1040 hex map for 《我带着AI穿越大宋》.

64×68 pointy-top hexes over a Lambert conformal conic of the Song/Liao/Xia
region. This is a scripted geographic approximation (not ETOPO/CHGIS).
Outputs:
  data/map/map_1040.json
  data/cities.json
  docs/map_preview.png
"""

from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H = 64, 68
LON_MIN, LON_MAX = 94.0, 128.0
LAT_MIN, LAT_MAX = 20.0, 46.0
LON0, LAT0, LAT1, LAT2 = 112.0, 33.0, 25.0, 45.0
EARTH_A = 6378137.0

# Axial neighbor order. Must match scripts/core/hex_grid.gd.
DIRS = ((1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1))
DIR_TO_I = {d: i for i, d in enumerate(DIRS)}

TERRAIN_CHAR = {
    "plain": "p",
    "grass": "g",
    "hill": "h",
    "mountain": "m",
    "alpine": "a",
    "loess": "l",
    "forest": "f",
    "marsh": "w",
    "desert": "d",
    "erg": "e",
    "rice": "r",
    "lake": "k",
    "sea": "s",
}
OWNER_CHAR = {
    "": ".",
    "song": "S",
    "xia": "X",
    "liao": "L",
    "gusiluo": "G",
    "dali": "D",
    "goryeo": "K",
    "jiaozhi": "J",
    "uyghur": "U",
}

# id, name, short, faction, level, capital, major, lon, lat, circuit
CITIES = [
    ("kaifeng", "东京开封府", "开封", "song", "jing", True, True, 114.35, 34.80, "京畿"),
    ("luoyang", "西京河南府", "洛阳", "song", "jing", False, True, 112.45, 34.62, "京西"),
    ("shangqiu", "南京应天府", "应天", "song", "jing", False, False, 115.65, 34.41, "京东"),
    ("daming", "大名府", "大名", "song", "fu", False, True, 115.15, 36.28, "河北"),
    ("jingzhao", "京兆府", "京兆", "song", "fu", False, True, 108.94, 34.26, "陕西"),
    ("yanzhou", "延州", "延州", "song", "zhou", False, True, 109.49, 36.65, "陕西"),
    ("qingyang", "庆州", "庆州", "song", "zhou", False, False, 107.64, 35.73, "陕西"),
    ("huanzhou", "环州", "环州", "song", "zhou", False, False, 107.30, 36.58, "陕西"),
    ("weizhou", "渭州", "渭州", "song", "zhou", False, True, 106.68, 35.54, "陕西"),
    ("yuanzhou", "原州", "原州", "song", "zhou", False, False, 107.20, 35.68, "陕西"),
    ("zhenrong", "镇戎军", "镇戎", "song", "jun", False, False, 106.28, 36.02, "陕西"),
    ("qinzhou", "秦州", "秦州", "song", "zhou", False, True, 105.72, 34.58, "陕西"),
    ("linzhou", "麟州", "麟州", "song", "zhou", False, False, 110.50, 38.84, "河东"),
    ("fuzhou_fu", "府州", "府州", "song", "zhou", False, False, 111.07, 39.03, "河东"),
    ("taiyuan", "太原府", "太原", "song", "fu", False, True, 112.55, 37.87, "河东"),
    ("daizhou", "代州", "代州", "song", "zhou", False, False, 112.96, 39.07, "河东"),
    ("zhending", "真定府", "真定", "song", "fu", False, True, 114.57, 38.15, "河北"),
    ("dingzhou", "定州", "定州", "song", "zhou", False, False, 114.99, 38.52, "河北"),
    ("xiongzhou", "雄州", "雄州", "song", "zhou", False, False, 116.10, 39.04, "河北"),
    ("cangzhou", "沧州", "沧州", "song", "zhou", False, False, 116.84, 38.30, "河北"),
    ("chanzhou", "澶州", "澶州", "song", "zhou", False, False, 115.03, 35.71, "河北"),
    ("beizhou", "贝州", "贝州", "song", "zhou", False, False, 115.67, 37.07, "河北"),
    ("qingzhou", "青州", "青州", "song", "zhou", False, False, 118.48, 36.69, "京东"),
    ("yizhou", "沂州", "沂州", "song", "zhou", False, False, 118.36, 35.10, "京东"),
    ("dengzhou", "登州", "登州", "song", "zhou", False, False, 120.76, 37.81, "京东"),
    ("xuzhou", "徐州", "徐州", "song", "zhou", False, False, 117.18, 34.26, "京东"),
    ("yangzhou", "扬州", "扬州", "song", "zhou", False, False, 119.42, 32.39, "淮南"),
    ("jiangning", "江宁府", "江宁", "song", "fu", False, True, 118.78, 32.06, "江南"),
    ("suzhou", "苏州", "苏州", "song", "zhou", False, False, 120.59, 31.30, "两浙"),
    ("hangzhou", "杭州", "杭州", "song", "zhou", False, True, 120.16, 30.25, "两浙"),
    ("yuezhou", "越州", "越州", "song", "zhou", False, False, 120.58, 30.00, "两浙"),
    ("mingzhou", "明州", "明州", "song", "zhou", False, False, 121.55, 29.87, "两浙"),
    ("fuzhou", "福州", "福州", "song", "zhou", False, False, 119.30, 26.08, "福建"),
    ("quanzhou", "泉州", "泉州", "song", "zhou", False, False, 118.68, 24.87, "福建"),
    ("guangzhou", "广州", "广州", "song", "zhou", False, False, 113.26, 23.13, "广南"),
    ("guilin", "桂州", "桂州", "song", "zhou", False, False, 110.29, 25.27, "广南"),
    ("yongzhou", "邕州", "邕州", "song", "zhou", False, False, 108.37, 22.82, "广南"),
    ("tanzhou", "潭州", "潭州", "song", "zhou", False, False, 112.94, 28.23, "荆湖"),
    ("jiangling", "江陵府", "江陵", "song", "fu", False, False, 112.24, 30.33, "荆湖"),
    ("ezhou", "鄂州", "鄂州", "song", "zhou", False, False, 114.31, 30.55, "荆湖"),
    ("hongzhou", "洪州", "洪州", "song", "zhou", False, False, 115.86, 28.68, "江南"),
    ("xiangzhou", "襄州", "襄州", "song", "zhou", False, False, 112.14, 32.04, "京西"),
    ("xingyuan", "兴元府", "兴元", "song", "fu", False, False, 107.02, 33.07, "川峡"),
    ("chengdu", "成都府", "成都", "song", "fu", False, True, 104.07, 30.67, "川峡"),
    ("zizhou", "梓州", "梓州", "song", "zhou", False, False, 105.09, 31.13, "川峡"),
    ("kuizhou", "夔州", "夔州", "song", "zhou", False, False, 109.53, 31.02, "川峡"),
    ("youzhou", "南京析津府", "幽州", "liao", "jing", False, True, 116.40, 39.90, ""),
    ("datong", "大同府", "大同", "liao", "fu", False, False, 113.30, 40.08, ""),
    ("dading", "中京大定府", "中京", "liao", "jing", False, False, 119.32, 41.60, ""),
    ("linhuang", "上京临潢府", "上京", "liao", "jing", True, True, 119.35, 43.97, ""),
    ("liaoyang", "东京辽阳府", "辽阳", "liao", "jing", False, False, 123.17, 41.27, ""),
    ("zhuozhou", "涿州", "涿州", "liao", "zhou", False, False, 115.97, 39.49, ""),
    ("yuzhou", "蔚州", "蔚州", "liao", "zhou", False, False, 114.57, 39.84, ""),
    ("yingzhou", "应州", "应州", "liao", "zhou", False, False, 113.19, 39.55, ""),
    ("shuozhou", "朔州", "朔州", "liao", "zhou", False, False, 112.43, 39.33, ""),
    ("pingzhou", "平州", "平州", "liao", "zhou", False, False, 118.95, 39.90, ""),
    ("yingzhou_ying", "营州", "营州", "liao", "zhou", False, False, 120.45, 41.10, ""),
    ("yizhou_liao", "易州", "易州", "liao", "zhou", False, False, 115.50, 39.35, ""),
    ("xingqing", "兴庆府", "兴庆", "xia", "jing", True, True, 106.27, 38.47, ""),
    ("lingzhou", "灵州", "灵州", "xia", "fu", False, False, 106.34, 38.10, ""),
    ("xiazhou", "夏州", "夏州", "xia", "zhou", False, False, 108.85, 37.95, ""),
    ("yinzhou", "银州", "银州", "xia", "zhou", False, False, 109.73, 38.05, ""),
    ("youzhou_xia", "宥州", "宥州", "xia", "zhou", False, False, 107.98, 38.20, ""),
    ("yanzhou_salt", "盐州", "盐州", "xia", "zhou", False, False, 107.40, 37.78, ""),
    ("liangzhou", "西凉府", "凉州", "xia", "fu", False, False, 102.64, 37.93, ""),
    ("ganzhou", "甘州", "甘州", "xia", "zhou", False, False, 100.45, 38.93, ""),
    ("suzhou_xia", "肃州", "肃州", "xia", "zhou", False, False, 98.49, 39.73, ""),
    ("guazhou", "瓜州", "瓜州", "xia", "zhou", False, False, 95.78, 40.52, ""),
    ("shazhou", "沙州", "沙州", "xia", "zhou", False, False, 94.66, 40.14, ""),
    ("qingtang", "青唐城", "青唐", "gusiluo", "zhou", True, True, 101.78, 36.62, ""),
    ("miaochuan", "邈川", "邈川", "gusiluo", "zhou", False, False, 102.40, 36.48, ""),
    ("yangjumie", "羊苴咩城", "大理", "dali", "zhou", True, True, 100.27, 25.61, ""),
    ("shanchang", "善阐", "善阐", "dali", "zhou", False, False, 102.71, 25.04, ""),
    ("kaegyeong", "开京", "开京", "goryeo", "jing", True, True, 126.56, 37.97, ""),
    ("pyongyang", "西京平壤", "平壤", "goryeo", "fu", False, False, 125.75, 39.03, ""),
    ("thanglong", "升龙", "升龙", "jiaozhi", "zhou", True, True, 105.85, 21.03, ""),
    # West of Xia's Shazhou. Turpan is on the board; the hex is filled by tools/retouch_1040.py.
    ("xizhou", "西州高昌", "高昌", "uyghur", "zhou", True, False, 89.19, 42.95, ""),
]

OUTPUT = {
    "jing": (8, 12, 4),
    "fu": (5, 6, 3),
    "zhou": (3, 3, 1),
    "jun": (2, 2, 1),
}
POP = {"jing": 10, "fu": 6, "zhou": 4, "jun": 2}

# Eastern shore of the mainland: sea lies east of this longitude. Used south of Bohai.
# Chengshantou and the Yangtze mouth sit a little east of the previous polyline,
# which was cutting the Shandong tip and flattening the delta.
EAST_COAST = [
    (38.4, 122.55),
    (37.48, 122.85),
    (37.05, 122.55),
    (36.4, 120.95),
    (35.4, 119.85),
    (34.5, 119.55),
    (33.6, 120.45),
    (32.45, 121.25),
    (31.55, 121.98),
    (30.75, 122.08),
    (30.15, 121.9),
    (29.3, 121.75),
    (28.2, 121.1),
    (27.0, 120.6),
    (26.1, 119.8),
    (25.2, 119.4),
    (24.5, 118.6),
    (23.6, 117.1),
    (22.7, 115.4),
]
SOUTH_COAST = [
    (105.0, 20.3),
    (106.3, 21.35),
    (107.6, 21.55),
    (108.6, 21.45),
    (109.6, 21.35),
    (109.85, 21.1),
    (110.05, 20.48),
    (110.22, 20.26),
    (110.48, 20.72),
    (110.7, 21.22),
    (111.6, 21.45),
    (113.0, 21.95),
    (114.3, 22.45),
    (115.6, 22.75),
    (117.2, 23.45),
]
KOREA_WEST = [
    (41.2, 126.8),
    (40.2, 124.55),
    (39.3, 125.15),
    (38.2, 125.45),
    (37.6, 126.25),
    (36.5, 126.35),
    (35.2, 126.25),
    (34.3, 126.6),
]
BOHAI = [
    (117.85, 38.50),
    (117.72, 38.95),
    (118.10, 39.12),
    (118.70, 39.08),
    (119.20, 39.25),
    (119.75, 39.60),
    (120.30, 40.00),
    (120.85, 40.40),
    (121.20, 40.75),
    (121.60, 40.40),
    (121.45, 39.85),
    (121.30, 39.30),
    (121.40, 38.75),
    (121.25, 38.35),
    (120.85, 38.05),
    (120.30, 37.98),
    (119.40, 37.95),
    (118.70, 38.10),
    (118.15, 38.30),
]
TAIWAN = [
    (121.0, 25.25),
    (121.85, 25.05),
    (121.95, 23.6),
    (121.4, 22.15),
    (120.75, 22.0),
    (120.05, 22.7),
    (120.15, 24.4),
    (120.7, 25.15),
]
# Hainan sits south of the mainland coast test, so it has to be forced to land
# the same way Taiwan is. The Qiongzhou strait stays the gap above this ring.
HAINAN = [
    (110.02, 20.16),
    (110.48, 20.1),
    (110.9, 19.92),
    (111.03, 19.5),
    (110.9, 19.05),
    (110.45, 18.55),
    (109.95, 18.22),
    (109.35, 18.15),
    (108.85, 18.4),
    (108.58, 18.85),
    (108.6, 19.35),
    (108.9, 19.78),
    (109.4, 20.02),
    (109.78, 20.12),
]

QINLING = [(106.2, 34.05), (107.4, 33.85), (108.6, 33.95), (109.8, 34.05), (110.8, 33.85), (111.6, 33.55)]
DABA = [(107.2, 32.45), (108.4, 32.25), (109.5, 32.05), (110.6, 31.85)]
TAIHANG = [(113.35, 35.4), (113.7, 36.5), (113.95, 37.6), (114.2, 38.6), (114.55, 39.5), (115.1, 40.25)]
YANSHAN = [(115.8, 40.45), (117.2, 40.55), (118.6, 40.45), (119.6, 40.35)]
YINSHAN = [(107.0, 41.15), (109.0, 41.05), (111.0, 41.0), (113.2, 41.15)]
HELAN = [(105.95, 37.7), (106.15, 38.4), (106.30, 39.15)]
LIUPAN = [(106.15, 35.25), (106.30, 35.7), (106.45, 36.15)]
LVLANG = [(110.9, 36.3), (111.25, 37.4), (111.55, 38.4)]
QILIAN = [(96.2, 39.35), (98.0, 38.85), (99.8, 38.35), (101.5, 37.85), (102.8, 37.35)]
WUYI = [(116.6, 25.3), (117.6, 26.5), (118.2, 27.6), (118.6, 28.3)]
NANLING = [(110.2, 25.05), (111.8, 25.25), (113.4, 25.05), (114.8, 25.35)]
DABIE = [(114.6, 31.15), (115.6, 31.35), (116.5, 31.55)]
FUNIU = [(111.6, 33.7), (112.4, 33.85), (113.1, 33.7)]

YELLOW = [
    (102.2, 35.95), (103.0, 36.02), (103.83, 36.06), (104.3, 36.40), (104.8, 36.85),
    (105.15, 37.25), (105.45, 37.70), (105.90, 38.15), (106.27, 38.48), (106.60, 38.95),
    (106.90, 39.45), (107.40, 40.05), (108.10, 40.45), (108.90, 40.68), (109.70, 40.72),
    (110.40, 40.55), (110.90, 40.20), (111.15, 39.65), (111.05, 39.05), (110.85, 38.40),
    (110.60, 37.70), (110.45, 37.00), (110.38, 36.30), (110.32, 35.50), (110.28, 34.62),
    (110.80, 34.68), (111.50, 34.80), (112.30, 34.84), (113.10, 34.92), (113.70, 34.96),
    # 1048 商胡决口之前的京东故道：过澶、大名，于滨州入渤海西南，不入海河。
    (114.25, 35.02), (114.65, 35.25), (115.00, 35.68), (115.25, 36.15), (115.40, 36.35),
    (115.90, 36.72), (116.45, 37.05), (117.05, 37.38), (117.55, 37.62), (118.05, 37.92),
    (118.40, 38.45),
]
YANGTZE = [
    (101.6, 26.6), (102.5, 27.2), (103.4, 28.2), (104.6, 28.77), (105.4, 28.90),
    (106.55, 29.57), (107.6, 30.05), (108.5, 30.85), (109.5, 31.05), (110.4, 31.05),
    (111.30, 30.70), (112.20, 30.32), (113.10, 29.85), (114.30, 30.55), (115.40, 30.15),
    (116.05, 29.75), (117.05, 30.50), (118.05, 31.35), (118.80, 32.10), (119.55, 32.22),
    (120.30, 32.02), (120.90, 31.75),
]
HUAI = [(113.6, 32.25), (114.8, 32.45), (116.0, 32.65), (117.2, 32.95), (118.3, 33.25), (119.15, 33.55), (119.85, 33.85)]
HAN = [(106.9, 33.10), (108.0, 32.95), (109.5, 32.55), (110.8, 32.45), (112.15, 32.04), (113.2, 31.15), (114.25, 30.58)]
WEI = [(106.2, 34.55), (107.4, 34.40), (108.4, 34.32), (108.94, 34.28), (109.8, 34.40), (110.30, 34.62)]
FEN = [(112.15, 38.55), (112.55, 37.87), (112.10, 36.90), (111.40, 36.05), (110.55, 35.55)]
BIAN = [(114.35, 34.75), (115.10, 34.55), (115.65, 34.40), (116.60, 34.25), (117.20, 34.26), (118.10, 33.70), (118.90, 33.50)]
CANAL = [(119.42, 32.39), (119.55, 32.15), (120.00, 31.75), (120.30, 31.50), (120.59, 31.30), (120.75, 30.85), (120.40, 30.40), (120.16, 30.25)]
PEARL = [(110.6, 23.85), (111.8, 23.45), (112.9, 23.20), (113.26, 23.13), (113.55, 22.75)]
XIANG = [(112.55, 26.6), (112.94, 28.23), (113.05, 29.30)]
GAN = [(114.9, 26.0), (115.4, 27.2), (115.86, 28.68), (116.25, 29.30)]

LAKES = [
    ("qinghai", 100.15, 36.88, 55),
    ("dongting", 112.80, 29.05, 62),
    ("poyang", 116.40, 29.20, 55),
    ("taihu", 120.12, 31.12, 22),
    ("liangshan", 116.08, 35.90, 68),
    ("dianchi", 102.66, 24.68, 14),
]

FEATURES = [
    ("salt", "盐", 110.95, 34.82),
    ("salt", "盐", 107.45, 37.70),
    ("iron", "铁", 114.38, 36.40),
    ("iron", "铁", 117.35, 34.45),
    ("coal", "煤", 112.30, 37.75),
    ("coal", "煤", 114.15, 36.55),
    ("copper", "铜", 117.95, 28.45),
    ("copper", "铜", 113.60, 24.82),
    ("tea", "茶", 118.15, 27.20),
    ("tea", "茶", 103.55, 30.15),
    ("silk", "丝", 115.30, 37.70),
    ("silk", "丝", 103.85, 30.55),
    ("horse", "马", 102.10, 36.90),
    ("horse", "马", 103.40, 37.30),
    ("saltpeter", "硝", 111.40, 35.40),
]
PASSES = [
    ("潼关", 110.25, 34.50),
    ("雁门关", 112.86, 39.18),
    ("居庸关", 116.07, 40.29),
    ("古北口", 117.16, 40.68),
    ("剑门关", 105.56, 32.22),
    ("萧关", 106.18, 36.08),
    ("金锁关", 108.92, 35.28),
]


def lambert(lon: float, lat: float) -> tuple[float, float]:
    phi = math.radians(lat)
    lam = math.radians(lon)
    phi0 = math.radians(LAT0)
    phi1 = math.radians(LAT1)
    phi2 = math.radians(LAT2)
    lam0 = math.radians(LON0)

    def t_of(p: float) -> float:
        return math.tan(math.pi / 4 + p / 2)

    n = math.log(math.cos(phi1) / math.cos(phi2)) / math.log(t_of(phi2) / t_of(phi1))
    f = math.cos(phi1) * (t_of(phi1) ** n) / n
    rho = EARTH_A * f / (t_of(phi) ** n)
    rho0 = EARTH_A * f / (t_of(phi0) ** n)
    x = rho * math.sin(n * (lam - lam0))
    y = rho0 - rho * math.cos(n * (lam - lam0))
    return x / 1000.0, y / 1000.0


def lambert_inverse(x_km: float, y_km: float) -> tuple[float, float]:
    phi1 = math.radians(LAT1)
    phi2 = math.radians(LAT2)
    phi0 = math.radians(LAT0)
    lam0 = math.radians(LON0)

    def t_of(p: float) -> float:
        return math.tan(math.pi / 4 + p / 2)

    n = math.log(math.cos(phi1) / math.cos(phi2)) / math.log(t_of(phi2) / t_of(phi1))
    f = math.cos(phi1) * (t_of(phi1) ** n) / n
    rho0 = EARTH_A * f / (t_of(phi0) ** n)
    x = x_km * 1000.0
    y = y_km * 1000.0
    sign = 1 if n >= 0 else -1
    rho = sign * math.hypot(x, rho0 - y)
    theta = math.atan2(x, rho0 - y)
    t = (EARTH_A * f / rho) ** (1.0 / n)
    phi = 2 * math.atan(t) - math.pi / 2
    lam = lam0 + theta / n
    return math.degrees(lam), math.degrees(phi)


def interp(x: float, pts: list[tuple[float, float]]) -> float:
    pts = sorted(pts, key=lambda p: p[0])
    if x <= pts[0][0]:
        return pts[0][1]
    if x >= pts[-1][0]:
        return pts[-1][1]
    for i in range(1, len(pts)):
        x0, y0 = pts[i - 1]
        x1, y1 = pts[i]
        if x <= x1:
            t = (x - x0) / (x1 - x0) if x1 != x0 else 0.0
            return y0 + t * (y1 - y0)
    return pts[-1][1]


def in_poly(lon: float, lat: float, poly: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > lat) != (yj > lat):
            xint = (xj - xi) * (lat - yi) / ((yj - yi) or 1e-12) + xi
            if lon < xint:
                inside = not inside
        j = i
    return inside


def dist_km(lon: float, lat: float, pts: list[tuple[float, float]]) -> float:
    lat0 = math.radians(lat)
    kx = 111.32 * math.cos(lat0)
    ky = 110.57
    px, py = lon * kx, lat * ky
    best = 1e9
    for i in range(len(pts) - 1):
        ax, ay = pts[i][0] * kx, pts[i][1] * ky
        bx, by = pts[i + 1][0] * kx, pts[i + 1][1] * ky
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        if l2 < 1e-6:
            best = min(best, math.hypot(px - ax, py - ay))
            continue
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
        best = min(best, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return best


def hash01(lon: float, lat: float) -> float:
    x = int(lon * 40) * 374761393 + int(lat * 40) * 668265263
    x = (x ^ (x >> 13)) * 1274126177
    x = x ^ (x >> 16)
    return (x & 0xFFFF) / 65535.0


def in_korea(lon: float, lat: float) -> bool:
    if lat < 34.25 or lat > 42.6 or lon < 124.3:
        return False
    yalu = interp(lon, [(124.4, 39.85), (126.0, 40.55), (128.0, 41.75)])
    if lat > yalu:
        return False
    return lon >= interp(lat, KOREA_WEST)


def in_liaodong(lon: float, lat: float) -> bool:
    if lat < 38.75 or lat > 42.2 or lon < 120.8 or lon > 124.8:
        return False
    west = interp(lat, [(42.0, 121.0), (40.6, 121.15), (39.6, 121.25), (38.85, 121.15)])
    east = interp(lat, [(42.0, 124.6), (41.0, 124.2), (40.0, 123.4), (39.2, 122.6), (38.85, 122.15)])
    return west <= lon <= east


def in_taiwan(lon: float, lat: float) -> bool:
    return in_poly(lon, lat, TAIWAN)


def in_hainan(lon: float, lat: float) -> bool:
    return in_poly(lon, lat, HAINAN)


def is_sea(lon: float, lat: float) -> bool:
    if in_taiwan(lon, lat) or in_hainan(lon, lat):
        return False
    if in_korea(lon, lat) or in_liaodong(lon, lat):
        return False
    if in_poly(lon, lat, BOHAI):
        return True
    if 105.0 <= lon <= 117.4 and lat < interp(lon, SOUTH_COAST):
        return True
    if lat <= 38.55 and lon > interp(lat, EAST_COAST):
        return True
    # Korea Bay, between the Liaodong peninsula and the Korean west coast.
    if 38.55 < lat <= 40.25 and lon >= 122.7:
        return True
    return False


def lake_at(lon: float, lat: float) -> str:
    for name, clon, clat, radius in LAKES:
        dlat = (lat - clat) * 110.57
        dlon = (lon - clon) * 111.32 * math.cos(math.radians(clat))
        if dlat * dlat + dlon * dlon <= radius * radius:
            return name
    return ""


def hexi_oasis(lon: float, lat: float) -> bool:
    if not 94.3 <= lon <= 104.0:
        return False
    center = interp(lon, [(94.5, 40.15), (96.0, 40.35), (98.5, 39.75), (100.5, 38.95), (102.6, 37.95), (103.8, 36.15)])
    return abs(lat - center) <= 0.38


def in_sichuan(lon: float, lat: float) -> bool:
    dx = (lon - 105.35) / 2.15
    dy = (lat - 30.45) / 1.45
    return dx * dx + dy * dy < 1.0


def classify(lon: float, lat: float) -> str:
    if is_sea(lon, lat):
        return "sea"
    if lake_at(lon, lat):
        return "lake"
    # Impassable high country: plateau edge, Hengduan cores, Qilian crest.
    if lon <= 99.2 and 29.0 <= lat <= 36.8 and not hexi_oasis(lon, lat):
        return "alpine"
    if 97.0 <= lon <= 102.2 and 26.0 <= lat <= 33.2 and hash01(lon, lat) > 0.55 and not in_sichuan(lon, lat):
        return "alpine"
    if dist_km(lon, lat, QILIAN) < 22 and not hexi_oasis(lon, lat):
        return "alpine"
    if lat < 28.0 and lon < 98.5:
        return "alpine"
    # Mountain ranges.
    if dist_km(lon, lat, QINLING) < 38:
        return "mountain"
    if dist_km(lon, lat, DABA) < 32 and not in_sichuan(lon, lat):
        return "mountain"
    if dist_km(lon, lat, TAIHANG) < 28:
        return "mountain"
    if dist_km(lon, lat, YANSHAN) < 26:
        return "mountain"
    if dist_km(lon, lat, YINSHAN) < 30:
        return "mountain"
    if 105.95 <= lon <= 106.9 and 37.45 <= lat <= 39.2:
        return "plain"
    if dist_km(lon, lat, HELAN) < 14 and not (106.15 <= lon <= 106.85 and 37.7 <= lat <= 39.15):
        return "mountain"
    if dist_km(lon, lat, LIUPAN) < 22:
        return "mountain"
    if dist_km(lon, lat, LVLANG) < 26:
        return "mountain"
    if dist_km(lon, lat, QILIAN) < 48 and not hexi_oasis(lon, lat):
        return "mountain"
    if dist_km(lon, lat, WUYI) < 32:
        return "forest"
    if dist_km(lon, lat, NANLING) < 36:
        return "mountain"
    if dist_km(lon, lat, DABIE) < 28:
        return "forest"
    if 97.0 <= lon <= 102.6 and 26.0 <= lat <= 33.6 and not in_sichuan(lon, lat):
        return "mountain"
    if hexi_oasis(lon, lat):
        return "plain"
    # Deserts of the northwest. 荒漠 (desert) vs 沙海 (erg).
    if 107.7 <= lon <= 110.15 and 37.55 <= lat <= 39.35:
        return "desert"
    if 103.0 <= lon <= 105.9 and 37.45 <= lat <= 39.55:
        return "erg"
    if 99.6 <= lon <= 103.3 and 39.05 <= lat <= 41.15:
        return "erg"
    if 104.6 <= lon <= 107.6 and 38.9 <= lat <= 41.15 and dist_km(lon, lat, HELAN) >= 18:
        return "desert"
    # Loess plateau, with the Guanzhong and Taiyuan basins carved out later.
    if 106.3 <= lon <= 111.15 and 35.05 <= lat <= 38.7:
        if not (107.7 <= lon <= 110.4 and 34.15 <= lat <= 34.75):
            if not (111.6 <= lon <= 113.2 and 37.0 <= lat <= 38.3):
                return "loess"
    # Basins and agricultural plains.
    if in_sichuan(lon, lat):
        return "rice"
    if 106.2 <= lon <= 107.7 and 32.85 <= lat <= 33.45:
        return "plain"
    if 107.7 <= lon <= 110.35 and 34.12 <= lat <= 34.72:
        return "plain"
    if 112.0 <= lon <= 113.15 and 37.15 <= lat <= 38.25:
        return "plain"
    if 112.7 <= lon <= 114.1 and 39.55 <= lat <= 40.45:
        return "grass"
    if 112.0 <= lon <= 114.7 and 29.95 <= lat <= 31.25:
        return "rice"
    if 111.6 <= lon <= 113.7 and 28.35 <= lat <= 29.7 and lake_at(lon, lat) == "":
        return "rice"
    if 115.4 <= lon <= 117.2 and 28.2 <= lat <= 29.7 and lake_at(lon, lat) == "":
        return "rice"
    if 119.5 <= lon <= 121.35 and 30.85 <= lat <= 32.25 and not is_sea(lon, lat):
        return "rice"
    if 119.7 <= lon <= 121.2 and 29.75 <= lat <= 30.7:
        return "rice"
    if 112.6 <= lon <= 113.6 and 27.6 <= lat <= 28.6:
        return "rice"
    if 115.4 <= lon <= 116.3 and 28.2 <= lat <= 29.0:
        return "rice"
    if 112.7 <= lon <= 114.0 and 22.45 <= lat <= 23.45:
        return "rice"
    # Hebei defensive marshes, Song side of the border.
    if 115.9 <= lon <= 117.6 and 38.85 <= lat <= 39.32 and not is_sea(lon, lat):
        return "marsh"
    # North China plain.
    if 113.7 <= lon <= 122.2 and 32.3 <= lat <= 40.2 and not is_sea(lon, lat):
        dx = (lon - 118.0) / 1.35
        dy = (lat - 36.35) / 0.85
        if dx * dx + dy * dy < 1.0 and lat < 37.6:
            return "hill"
        if lat < 39.35:
            return "plain"
    # Steppe and Manchurian forest.
    if lat >= 41.0 and lon >= 124.0 and not is_sea(lon, lat):
        return "forest" if hash01(lon, lat) > 0.35 else "hill"
    if lat >= 41.15 and not is_sea(lon, lat):
        return "grass"
    # South of the Yangtze: hills and forest, remaining pockets.
    if lat < 33.0:
        return "forest" if hash01(lon, lat) > 0.58 else "hill"
    if dist_km(lon, lat, FUNIU) < 40:
        return "hill"
    if lat >= 38.5:
        return "grass"
    return "plain"


def _hengshan_lat(lon: float) -> float:
    # Song–Xia frontier along the Hengshan, north of 延州 / 庆州 / 环州.
    # Xia is north of the line. 麟州 and 府州 stay south and east of it.
    return interp(lon, [
        (106.3, 36.30),
        (107.3, 37.20),
        (108.3, 37.42),
        (109.3, 37.48),
        (110.15, 37.62),
    ])


def _song_liao_lat(lon: float) -> float:
    # Liao is north of this line: 白沟 / 拒马河 to the Yanmen notch.
    # 朔州 (112.6°E) shares a hex row with 代州, so the line dips there.
    return interp(lon, [
        (111.15, 39.42),
        (111.85, 39.28),
        (112.40, 38.92),
        (112.95, 38.96),
        (113.20, 39.32),
        (114.4, 39.55),
        (115.25, 39.32),
        (116.00, 39.22),
        (116.8, 39.16),
        (117.7, 39.02),
        (119.9, 39.28),
    ])


def is_uyghur(lon: float, lat: float) -> bool:
    # 西州回鹘, Gaochang / Turpan. Meets Xia west of Shazhou; Shazhou itself stays Xia.
    if 87.0 <= lon <= 94.3 and 41.05 <= lat <= 45.2:
        return True
    if 92.2 <= lon <= 94.3 and 40.15 <= lat < 41.05:
        return True
    return False


def _song_sichuan_rim(lon: float, lat: float) -> bool:
    # 雅州、黎州 stay in 川峡. The high plateau west of this box is Tibetan.
    return 102.5 <= lon <= 104.6 and 28.7 <= lat <= 32.4


def is_xia(lon: float, lat: float) -> bool:
    # Hexi corridor (沙州 through 凉州), the Ordos, and the land north of Hengshan.
    if 94.2 <= lon <= 104.15 and 37.50 <= lat <= 41.55:
        return True
    if 104.15 < lon <= 107.15 and 36.95 <= lat <= 41.15:
        return True
    if 107.15 < lon <= 110.15 and _hengshan_lat(lon) <= lat <= 40.35:
        return True
    return False


def is_liao(lon: float, lat: float) -> bool:
    if is_xia(lon, lat) or in_korea(lon, lat) or is_uyghur(lon, lat):
        return False
    # Mongolian plateau on this board, and the steppe north of the Ordos.
    if lat >= 41.15 and lon >= 87.0:
        return True
    if lat >= 40.20 and 104.5 <= lon <= 111.20:
        return True
    if 111.15 <= lon <= 119.9 and lat >= _song_liao_lat(lon):
        return True
    if lon >= 119.3 and lat >= 39.6 and not in_korea(lon, lat):
        return True
    return False


def is_jiaozhi(lon: float, lat: float) -> bool:
    # The Red River delta. Specks farther south are the gulf, not Lý territory.
    return 20.3 <= lat < 21.85 and 104.6 <= lon <= 108.25 and not is_sea(lon, lat)


def is_dali(lon: float, lat: float) -> bool:
    if is_sea(lon, lat):
        return False
    return lon <= 104.2 and 21.55 <= lat <= 27.7


def is_gusiluo(lon: float, lat: float) -> bool:
    # 唃厮啰 at 青唐, plus the Tibetan tribes west of 秦州 and the Sichuan rim.
    if is_xia(lon, lat) or is_dali(lon, lat):
        return False
    if _song_sichuan_rim(lon, lat):
        return False
    if 98.6 <= lon <= 104.55 and 33.9 <= lat <= 37.55:
        return True
    # Meets Dali along ~27.7°N. East edge stops so 雅州 stays Song.
    if 97.2 <= lon <= 103.45 and 27.7 <= lat < 33.9 and not in_sichuan(lon, lat):
        return True
    return False


def faction_of(lon: float, lat: float, terrain: str) -> str:
    # Alpine crests stay inside the realm. Only open water is unowned, so the
    # territory outline is the state frontier and the coastline, not every ridge.
    if terrain in ("sea", "lake"):
        return ""
    if in_taiwan(lon, lat):
        return ""
    if in_korea(lon, lat):
        return "goryeo"
    if is_jiaozhi(lon, lat):
        return "jiaozhi"
    if is_uyghur(lon, lat):
        return "uyghur"
    if is_dali(lon, lat):
        return "dali"
    if _song_sichuan_rim(lon, lat) or in_sichuan(lon, lat):
        return "song"
    if is_gusiluo(lon, lat):
        return "gusiluo"
    if is_xia(lon, lat):
        return "xia"
    if is_liao(lon, lat):
        return "liao"
    if 108.4 <= lon <= 111.2 and 18.0 <= lat <= 20.3:
        return "song"
    if lon >= 103.4 and 20.2 <= lat <= 41.05:
        return "song"
    # 麟府 salient on the east bank of the great bend.
    if 110.15 <= lon <= 111.5 and 37.55 <= lat <= 39.4:
        return "song"
    return ""


def axial_dist(a: tuple[int, int], b: tuple[int, int]) -> int:
    return (abs(a[0] - b[0]) + abs(a[0] + a[1] - b[0] - b[1]) + abs(a[1] - b[1])) // 2


def axial_round(qf: float, rf: float) -> tuple[int, int]:
    xf, zf = qf, rf
    yf = -xf - zf
    x, y, z = round(xf), round(yf), round(zf)
    dx, dy, dz = abs(x - xf), abs(y - yf), abs(z - zf)
    if dx > dy and dx > dz:
        x = -y - z
    elif dy > dz:
        y = -x - z
    else:
        z = -x - y
    return int(x), int(z)


def offset_to_axial(col: int, row: int) -> tuple[int, int]:
    q = col - (row - (row & 1)) // 2
    return q, row


def axial_to_offset(q: int, r: int) -> tuple[int, int]:
    col = q + (r - (r & 1)) // 2
    return col, r


class Layout:
    def __init__(self) -> None:
        pts = []
        for lon in range(int(LON_MIN), int(LON_MAX) + 1):
            pts.append(lambert(lon, LAT_MIN))
            pts.append(lambert(lon, LAT_MAX))
        for lat in range(int(LAT_MIN), int(LAT_MAX) + 1):
            pts.append(lambert(LON_MIN, lat))
            pts.append(lambert(LON_MAX, lat))
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        self.bbox = (min(xs), max(xs), min(ys), max(ys))
        self.col_w = 50.0
        self.row_h = 50.0 * math.sqrt(3) / 2
        self.origin_x = 0.0
        self.origin_y = 0.0
        self._place(50.0)

    def _place(self, col_w: float) -> None:
        self.col_w = col_w
        self.row_h = col_w * math.sqrt(3) / 2
        sx = 0.0
        sy = 0.0
        n = W * H
        for row in range(H):
            for col in range(W):
                q, r = offset_to_axial(col, row)
                sx += q + r / 2
                sy += r
        ax, ay = sx / n, sy / n
        cx = (self.bbox[0] + self.bbox[1]) / 2
        cy = (self.bbox[2] + self.bbox[3]) / 2
        self.origin_x = cx - self.col_w * ax
        self.origin_y = cy + self.row_h * ay

    def world_to_axial(self, x: float, y: float) -> tuple[int, int]:
        rf = (self.origin_y - y) / self.row_h
        qf = (x - self.origin_x) / self.col_w - rf / 2
        return axial_round(qf, rf)

    def latlon_to_axial(self, lon: float, lat: float) -> tuple[int, int]:
        x, y = lambert(lon, lat)
        return self.world_to_axial(x, y)

    def axial_to_km(self, q: int, r: int) -> tuple[float, float]:
        x = self.origin_x + self.col_w * (q + r / 2)
        y = self.origin_y - self.row_h * r
        return x, y

    def contains(self, q: int, r: int, margin: int = 0) -> bool:
        col, row = axial_to_offset(q, r)
        return margin <= col < W - margin and margin <= row < H - margin

    def fit(self) -> None:
        samples = []
        for lon in (LON_MIN + 0.2, LON_MAX - 0.2):
            for lat in (LAT_MIN + 0.2, (LAT_MIN + LAT_MAX) / 2, LAT_MAX - 0.2):
                samples.append((lon, lat))
        for lat in (LAT_MIN + 0.2, LAT_MAX - 0.2):
            samples.append(((LON_MIN + LON_MAX) / 2, lat))
        for c in CITIES:
            samples.append((c[7], c[8]))

        def ok(col_w: float, margin_cities: bool) -> bool:
            self._place(col_w)
            for lon, lat in samples:
                q, r = self.latlon_to_axial(lon, lat)
                margin = 0
                if not self.contains(q, r, margin):
                    return False
            if margin_cities:
                for c in CITIES:
                    q, r = self.latlon_to_axial(c[7], c[8])
                    if not self.contains(q, r, 0):
                        return False
            return True

        lo, hi = 35.0, 70.0
        if not ok(hi, False):
            raise SystemExit("map extent cannot contain the region even at 70 km/hex")
        for _ in range(24):
            mid = (lo + hi) / 2
            if ok(mid, False):
                hi = mid
            else:
                lo = mid
        self._place(hi * 1.015)
        print(f"hex flat-to-flat {self.col_w:.2f} km, row {self.row_h:.2f} km")


def greedy_path(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
    path = [a]
    cur = a
    guard = 0
    while cur != b and guard < 8000:
        guard += 1
        best = None
        bestd = 10**9
        for dq, dr in DIRS:
            nb = (cur[0] + dq, cur[1] + dr)
            d = axial_dist(nb, b)
            if d < bestd:
                bestd = d
                best = nb
        if best is None or axial_dist(best, b) >= axial_dist(cur, b):
            break
        path.append(best)
        cur = best
    return path


def densify(pts: list[tuple[float, float]], step: float = 0.12) -> list[tuple[float, float]]:
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        dist = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(math.ceil(dist / step)))
        for i in range(1, n + 1):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def main() -> None:
    layout = Layout()
    layout.fit()

    terrain = {}
    owner = {}
    for row in range(H):
        for col in range(W):
            q, r = offset_to_axial(col, row)
            x, y = layout.axial_to_km(q, r)
            lon, lat = lambert_inverse(x, y)
            t = classify(lon, lat)
            terrain[(q, r)] = t
            owner[(q, r)] = faction_of(lon, lat, t)

    rivers: dict[tuple[int, int], int] = {}
    greats: dict[tuple[int, int], int] = {}

    def add_river(polyline: list[tuple[float, float]], great: bool) -> None:
        samples = [layout.latlon_to_axial(lon, lat) for lon, lat in densify(polyline)]
        chain = []
        for a, b in zip(samples, samples[1:]):
            part = greedy_path(a, b)
            if chain and part and chain[-1] == part[0]:
                chain.extend(part[1:])
            else:
                chain.extend(part)
        for a, b in zip(chain, chain[1:]):
            d = (b[0] - a[0], b[1] - a[1])
            if d not in DIR_TO_I:
                continue
            i = DIR_TO_I[d]
            j = (i + 3) % 6
            for hex_id, bit in ((a, i), (b, j)):
                if terrain.get(hex_id) == "sea":
                    continue
                rivers[hex_id] = rivers.get(hex_id, 0) | (1 << bit)
                if great:
                    greats[hex_id] = greats.get(hex_id, 0) | (1 << bit)

    add_river(YELLOW, True)
    add_river(YANGTZE, True)
    for line in (HUAI, HAN, WEI, FEN, BIAN, CANAL, PEARL, XIANG, GAN):
        add_river(line, False)

    features: dict[tuple[int, int], dict] = {}

    def place_feature(kind: str, name: str, lon: float, lat: float) -> None:
        q, r = layout.latlon_to_axial(lon, lat)
        if not layout.contains(q, r):
            print(f"feature off map: {name}")
            return
        # Nudge off a city-sized clash later; for now keep the nearest land hex.
        if terrain.get((q, r)) in ("sea", "lake"):
            found = None
            for rad in range(1, 4):
                for dq in range(-rad, rad + 1):
                    for dr in range(-rad, rad + 1):
                        if max(abs(dq), abs(dr), abs(-dq - dr)) != rad:
                            continue
                        nb = (q + dq, r + dr)
                        if terrain.get(nb) not in (None, "sea", "lake"):
                            found = nb
                            break
                    if found:
                        break
                if found:
                    break
            if not found:
                return
            q, r = found
        features[(q, r)] = {"id": kind, "name": name}

    for kind, name, lon, lat in FEATURES:
        place_feature(kind, name, lon, lat)
    for name, lon, lat in PASSES:
        place_feature("pass", name, lon, lat)
        q, r = layout.latlon_to_axial(lon, lat)
        if terrain.get((q, r)) == "alpine":
            terrain[(q, r)] = "mountain"

    # Cities.
    city_hex: dict[tuple[int, int], str] = {}
    city_rows = []
    for raw in CITIES:
        cid, name, short, fac, level, capital, major, lon, lat, circuit = raw
        q, r = layout.latlon_to_axial(lon, lat)
        if not layout.contains(q, r):
            raise SystemExit(f"city outside map: {name} {(q, r)}")
        natural = owner.get((q, r), "")
        if natural != fac:
            print(f"border fix {short}: map={natural or '空'} -> {fac} terrain={terrain.get((q, r))}")
        if (q, r) in city_hex:
            # Spiral to a free land hex.
            placed = False
            for rad in range(1, 5):
                for dq in range(-rad, rad + 1):
                    for dr in range(-rad, rad + 1):
                        if axial_dist((0, 0), (dq, dr)) != rad:
                            continue
                        nb = (q + dq, r + dr)
                        if nb in city_hex or not layout.contains(*nb):
                            continue
                        if terrain.get(nb) in ("sea", "lake", "alpine"):
                            continue
                        q, r = nb
                        placed = True
                        break
                    if placed:
                        break
                if placed:
                    break
            if not placed:
                raise SystemExit(f"no free hex for {name}")
            print(f"nudged {name} off a collision")
        if terrain.get((q, r)) in ("sea", "lake", "alpine", "marsh"):
            terrain[(q, r)] = "plain" if level != "jun" else "hill"
        if owner.get((q, r)) != fac:
            owner[(q, r)] = fac
        city_hex[(q, r)] = cid
        features.pop((q, r), None)
        col, row = axial_to_offset(q, r)
        x, y = layout.axial_to_km(q, r)
        elon, elat = lambert_inverse(x, y)
        food, money, craft = OUTPUT[level]
        city_rows.append(
            {
                "id": cid,
                "name": name,
                "short": short,
                "faction": fac,
                "level": level,
                "capital": capital,
                "major": major,
                "circuit": circuit,
                "lon": lon,
                "lat": lat,
                "hex_lon": round(elon, 2),
                "hex_lat": round(elat, 2),
                "q": q,
                "r": r,
                "col": col,
                "row": row,
                "pop": POP[level],
                "morale": 60,
                "walls": 8 if level in ("jing", "fu", "zhou") else 4,
                "output": {"food": food, "money": money, "craft": craft},
            }
        )

    # Bulk grids in offset order, row 0 = north.
    t_rows = []
    o_rows = []
    for row in range(H):
        tc = []
        oc = []
        for col in range(W):
            q, r = offset_to_axial(col, row)
            tc.append(TERRAIN_CHAR[terrain[(q, r)]])
            oc.append(OWNER_CHAR[owner[(q, r)]])
        t_rows.append("".join(tc))
        o_rows.append("".join(oc))

    river_list = []
    for (q, r), mask in sorted(rivers.items()):
        if mask:
            river_list.append([q, r, mask, greats.get((q, r), 0)])
    feature_list = []
    for (q, r), feat in sorted(features.items()):
        feature_list.append({"q": q, "r": r, "id": feat["id"], "name": feat["name"]})

    yan = next(c for c in city_rows if c["id"] == "yanzhou")
    mp = {
        "version": 1,
        "width": W,
        "height": H,
        "notes": "一版地理近似。兰伯特等角圆锥，标准纬线 25°N/45°N，中央经线 112°E。尖顶六边形，奇数行偏移。",
        "layout": {
            "col_w_km": round(layout.col_w, 4),
            "row_h_km": round(layout.row_h, 4),
            "origin_x_km": round(layout.origin_x, 4),
            "origin_y_km": round(layout.origin_y, 4),
            "lon0": LON0,
            "lat0": LAT0,
            "lat1": LAT1,
            "lat2": LAT2,
        },
        "terrain_legend": {v: k for k, v in TERRAIN_CHAR.items()},
        "owner_legend": {v: k for k, v in OWNER_CHAR.items()},
        "terrains": t_rows,
        "owners": o_rows,
        "rivers": river_list,
        "features": feature_list,
        "check": {"id": "yanzhou", "q": yan["q"], "r": yan["r"], "lon": yan["lon"], "lat": yan["lat"]},
    }

    map_path = ROOT / "data" / "map" / "map_1040.json"
    cities_path = ROOT / "data" / "cities.json"
    map_path.write_text(json.dumps(mp, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    cities_path.write_text(json.dumps({"cities": city_rows}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {map_path} ({map_path.stat().st_size} bytes), {len(city_rows)} cities, {len(river_list)} river hexes")

    by_id = {c["id"]: c for c in city_rows}

    def report(a: str, b: str) -> None:
        ca, cb = by_id[a], by_id[b]
        d = axial_dist((ca["q"], ca["r"]), (cb["q"], cb["r"]))
        print(f"  {ca['short']}—{cb['short']}: {d} 格")

    print("distances:")
    for pair in (
        ("kaifeng", "yanzhou"),
        ("yanzhou", "xingqing"),
        ("kaifeng", "youzhou"),
        ("kaifeng", "hangzhou"),
        ("kaifeng", "chengdu"),
        ("yanzhou", "qingyang"),
        ("kaifeng", "daming"),
    ):
        report(*pair)

    counts: dict[str, int] = {}
    for t in terrain.values():
        counts[t] = counts.get(t, 0) + 1
    print("terrain", counts)
    ocounts: dict[str, int] = {}
    for o in owner.values():
        ocounts[o or "none"] = ocounts.get(o or "none", 0) + 1
    print("owners", ocounts)

    sea_cities = [c["name"] for c in city_rows if terrain[(c["q"], c["r"])] == "sea"]
    if sea_cities:
        raise SystemExit(f"cities in sea: {sea_cities}")
    # Faction mismatches after override should be gone.
    bad = []
    for c in city_rows:
        if owner[(c["q"], c["r"])] != c["faction"]:
            bad.append(c["name"])
    if bad:
        raise SystemExit(f"owner mismatch: {bad}")

    write_preview(layout, terrain, owner, city_rows, rivers, greats)
    # Hard expectations from the GDD's distance feel.
    d_ky = axial_dist((by_id["kaifeng"]["q"], by_id["kaifeng"]["r"]), (by_id["yanzhou"]["q"], by_id["yanzhou"]["r"]))
    d_yx = axial_dist((by_id["yanzhou"]["q"], by_id["yanzhou"]["r"]), (by_id["xingqing"]["q"], by_id["xingqing"]["r"]))
    d_kn = axial_dist((by_id["kaifeng"]["q"], by_id["kaifeng"]["r"]), (by_id["youzhou"]["q"], by_id["youzhou"]["r"]))
    if not (8 <= d_ky <= 16 and 5 <= d_yx <= 12 and 8 <= d_kn <= 16):
        print("WARNING: anchor distances outside the design-doc ballpark")
    if counts.get("sea", 0) < 200:
        print("WARNING: very little sea — coastline may be closed")


PREVIEW_COLORS = {
    "plain": (214, 196, 138),
    "grass": (138, 168, 74),
    "hill": (176, 137, 88),
    "mountain": (125, 107, 88),
    "alpine": (214, 220, 224),
    "loess": (196, 149, 74),
    "forest": (47, 106, 56),
    "marsh": (90, 130, 106),
    "desert": (210, 181, 106),
    "erg": (226, 200, 120),
    "rice": (126, 162, 74),
    "lake": (74, 136, 176),
    "sea": (47, 95, 134),
}
FACTION_TINT = {
    "song": (44, 107, 90),
    "xia": (140, 50, 42),
    "liao": (166, 132, 46),
    "gusiluo": (106, 90, 138),
    "dali": (61, 106, 138),
    "goryeo": (42, 122, 122),
    "jiaozhi": (122, 122, 58),
}


def write_preview(layout: Layout, terrain, owner, cities, rivers, greats) -> None:
    from PIL import Image, ImageDraw, ImageFont

    hex_w = 16.0
    hex_h = 16.0 * math.sqrt(3) / 2
    size = hex_w / math.sqrt(3)  # center to vertex, flat-to-flat = hex_w
    margin = 28
    width = int(hex_w * (W + 0.6) + margin * 2)
    height = int(hex_h * (H + 0.6) + margin * 2 + 36)
    img = Image.new("RGB", (width, height), (244, 236, 214))
    draw = ImageDraw.Draw(img)

    def center(q: int, r: int) -> tuple[float, float]:
        col, row = axial_to_offset(q, r)
        x = margin + hex_w * (col + 0.5 * (row & 1))
        y = margin + hex_h * row
        return x, y

    def poly(q: int, r: int):
        cx, cy = center(q, r)
        pts = []
        for i in range(6):
            ang = math.radians(60 * i - 30)
            pts.append((cx + size * math.cos(ang), cy + size * math.sin(ang)))
        return pts

    for row in range(H):
        for col in range(W):
            q, r = offset_to_axial(col, row)
            base = PREVIEW_COLORS[terrain[(q, r)]]
            tint = FACTION_TINT.get(owner[(q, r)])
            if tint and terrain[(q, r)] not in ("sea", "lake"):
                colr = tuple(int(base[i] * 0.82 + tint[i] * 0.18) for i in range(3))
            else:
                colr = base
            draw.polygon(poly(q, r), fill=colr)

    # Faction borders and rivers.
    for row in range(H):
        for col in range(W):
            q, r = offset_to_axial(col, row)
            pts = poly(q, r)
            mask = rivers.get((q, r), 0)
            gmask = greats.get((q, r), 0)
            for i, (dq, dr) in enumerate(DIRS):
                nb = (q + dq, r + dr)
                if owner.get((q, r), "") and owner.get(nb, owner.get((q, r))) != owner.get((q, r)) and terrain[(q, r)] not in ("sea",):
                    a, b = pts[i], pts[(i + 1) % 6]
                    draw.line([a, b], fill=(40, 28, 22), width=1)
                if mask & (1 << i):
                    a, b = pts[i], pts[(i + 1) % 6]
                    colr = (20, 70, 130) if gmask & (1 << i) else (50, 120, 170)
                    draw.line([a, b], fill=colr, width=2 if gmask & (1 << i) else 1)

    font = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 11)
    title_font = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 16)
    for c in cities:
        cx, cy = center(c["q"], c["r"])
        r = 2 if c["level"] in ("zhou", "jun") else 3
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(120, 24, 18))
        label = c["short"]
        draw.text((cx + 4, cy - 6), label, font=font, fill=(20, 16, 12))
    draw.text((margin, height - 28), "庆历地图初稿 · 1040 · 尖顶六边形 · 约五十公里一格", font=title_font, fill=(40, 28, 22))
    out = ROOT / "docs" / "map_preview.png"
    img.save(out)
    print(f"wrote {out} {img.size}")


if __name__ == "__main__":
    main()
