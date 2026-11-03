#!/usr/bin/env python3
"""Генератор городов Sky Pilot: Дубай, Лондон, Ташкент.

Один источник данных для обеих версий игры:
  -> src/shared/CityData.luau   (Roblox: визуал + столкновения)
  -> tools/cities.json          (веб-версия)

Примитивы: box, cyl (ось X, как Cylinder в Roblox), ball, ell (эллипсоид), wedge (как WedgePart).
Поворот — эйлеровы углы XYZ: CFrame.Angles(rx, ry, rz) в Roblox == Euler('XYZ') в three.js.
Масштаб: 1 stud = 1.69 ft = 0.515 м, высоты знаковых зданий близки к настоящим.
Запуск: python3 tools/gen_cities.py
"""
import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M_PER_STUD = 0.515
rng = random.Random(4242)


def R(a, b):
    return a + (b - a) * rng.random()


def m2s(m):
    return m / M_PER_STUD


# ---------------------------------------------------------------- линейная алгебра
def rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def euler_m(e):
    return mul(mul(rx(e[0]), ry(e[1])), rz(e[2]))


def m_to_euler(M):
    b = math.asin(max(-1, min(1, M[0][2])))
    a = math.atan2(-M[1][2], M[2][2])
    c = math.atan2(-M[0][1], M[0][0])
    return (a, b, c)


def axis_to_euler(d):
    """Поворот, переводящий локальную ось X в направление d (для наклонных цилиндров)."""
    L = math.sqrt(sum(v * v for v in d))
    x = [v / L for v in d]
    up = [0, 1, 0] if abs(x[1]) < 0.95 else [1, 0, 0]
    z = [x[1] * up[2] - x[2] * up[1], x[2] * up[0] - x[0] * up[2], x[0] * up[1] - x[1] * up[0]]
    zl = math.sqrt(sum(v * v for v in z))
    z = [v / zl for v in z]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    M = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    return m_to_euler(M)


# ---------------------------------------------------------------- хранилище
props, obstacles, pads, labels = [], [], [], []


def hexc(c):
    return (c[0] << 16) | (c[1] << 8) | c[2]


def add(kind, p, s, e=(0, 0, 0), c=(200, 200, 200), m="SmoothPlastic", solid=True, refl=0.0, tr=0.0):
    props.append([kind, *[round(v, 2) for v in p], *[round(v, 2) for v in s], *[round(v, 4) for v in e], hexc(c), m, 1 if solid else 0, refl, tr])
    if solid:
        M = euler_m(e)
        h = [v / 2 for v in s]
        ext = [sum(abs(M[i][j]) * h[j] for j in range(3)) for i in range(3)]
        obstacles.append([round(p[i] - ext[i], 1) for i in range(3)] + [round(p[i] + ext[i], 1) for i in range(3)])


def box(p, s, ryaw=0.0, **k):
    add("box", p, s, (0, ryaw, 0), **k)


def vcyl(x, y0, z, h, d, **k):
    add("cyl", (x, y0 + h / 2, z), (h, d, d), (0, 0, math.pi / 2), **k)


def ball(p, d, **k):
    add("ball", p, (d, d, d), **k)


def ell(p, semi, **k):
    add("ell", p, tuple(v * 2 for v in semi), **k)


def wedge(p, s, e=(0, 0, 0), **k):
    add("wedge", p, s, e, **k)


def tilted_cyl(a, b, d, **k):
    mid = [(a[i] + b[i]) / 2 for i in range(3)]
    dv = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(v * v for v in dv))
    add("cyl", mid, (L, d, d), axis_to_euler(dv), **k)


def pad(cx, cz, half, h=0.45, c=(150, 150, 155)):
    pads.append([cx - half, cx + half, cz - half, cz + half, h])
    box((cx, h / 2, cz), (half * 2, h, half * 2), c=c, m="Concrete", solid=False)


def roads(cx, cz, half, step, offset=0.0):
    n = int(half * 2 // step)
    for i in range(n + 1):
        t = -half + offset + i * step
        if abs(t) > half:
            continue
        box((cx + t, 0.47, cz), (16, 0.05, half * 2), c=(55, 56, 60), m="Asphalt", solid=False)
        box((cx, 0.47, cz + t), (half * 2, 0.05, 16), c=(55, 56, 60), m="Asphalt", solid=False)


def free(x, z, zones):
    return all((x - zx) ** 2 + (z - zz) ** 2 > r * r for zx, zz, r in zones)


GLASS = [(120, 160, 190), (90, 130, 170), (170, 190, 205), (200, 180, 140), (60, 90, 120), (210, 215, 220), (140, 175, 165)]


def glass_tower(x, z, w, d, h, shape, col, ryaw=0.0):
    refl = 0.25
    if shape == "cyl":
        dd = min(w, d)
        vcyl(x, 0.45, z, h, dd, c=col, m="Glass", refl=refl)
        vcyl(x, 0.45 + h, z, h * 0.06, dd * 0.7, c=(220, 225, 230), m="Metal")
        vcyl(x, 0.45 + h * 1.06, z, h * 0.12, 2.5, c=(220, 225, 230), m="Metal")
    elif shape == "setback":
        y = 0.45
        for frac, sc in ((0.5, 1.0), (0.3, 0.75), (0.2, 0.5)):
            hh = h * frac
            box((x, y + hh / 2, z), (w * sc, hh, d * sc), ryaw, c=col, m="Glass", refl=refl)
            y += hh
        vcyl(x, y, z, h * 0.15, 3, c=(225, 225, 230), m="Metal")
    elif shape == "twist":
        n = 9
        for i in range(n):
            hh = h / n
            box((x, 0.45 + hh * (i + 0.5), z), (w * 0.85, hh, d * 0.85), ryaw + i * math.radians(9), c=col, m="Glass", refl=refl)
    else:
        box((x, 0.45 + h / 2, z), (w, h, d), ryaw, c=col, m="Glass", refl=refl)
        box((x, 0.45 + h + 3, z), (w * 0.6, 6, d * 0.6), ryaw, c=(70, 75, 80), m="Metal")
    if h > 260:
        ball((x, 0.45 + h * (1.2 if shape == "cyl" else 1.02) + 4, z), 3, c=(255, 50, 50), m="Neon", solid=False)


# ================================================================ ДУБАЙ
def dubai():
    cx, cz = 5500.0, -7500.0
    half = 1150
    pad(cx, cz, half, c=(196, 186, 165))
    roads(cx, cz, half, 145, 72.5)
    labels.append({"name": "DUBAI", "x": cx, "y": 1900, "z": cz})
    zones = [(cx, cz, 240)]
    for gx in range(-7, 8):
        for gz in range(-7, 8):
            x, z = cx + gx * 145, cz + gz * 145
            if not free(x, z, zones) or rng.random() > 0.82:
                continue
            dist = min(1.0, math.hypot(gx, gz) / 10)
            h = 60 + (1 - dist) ** 2 * R(250, 760) + R(0, 80)
            w, d = R(50, 95), R(50, 95)
            r = rng.random()
            shape = "cyl" if r < 0.25 else "setback" if r < 0.5 else "twist" if r < 0.62 else "box"
            glass_tower(x, z, w, d, h, shape, rng.choice(GLASS), R(0, 0.5) if shape == "box" else 0.0)

    # Бурдж-Халифа (828 м): Y-образный план из трёх крыльев, ступенчато сужается, шпиль
    top_body = m2s(585)
    tiers = 15
    th = top_body / tiers
    col = (195, 205, 215)
    for i in range(tiers):
        k = i / tiers
        L = 80 * (1 - k) ** 0.85 + 10
        core = 42 * (1 - k * 0.8)
        y = 0.45 + th * (i + 0.5)
        vcyl(cx, 0.45 + th * i, cz, th, core, c=col, m="Glass", refl=0.35)
        for j in range(3):
            a = math.radians(90 + j * 120)
            L_j = L * (1 - 0.18 * ((i + j) % 3 == 0 and i > 2))
            r = core * 0.3 + L_j / 2
            box((cx + math.cos(a) * r, y, cz - math.sin(a) * r), (L_j, th, 24 * (1 - k * 0.5)), a, c=col, m="Glass", refl=0.35)
    y = 0.45 + top_body
    for d, hh in ((14, m2s(90)), (9, m2s(70)), (5, m2s(55)), (2.2, m2s(28))):
        vcyl(cx, y, cz, hh, d, c=(225, 230, 235), m="Metal")
        y += hh
    ball((cx, y + 2, cz), 4, c=(255, 50, 50), m="Neon", solid=False)
    # фонтан и пруд у основания
    vcyl(cx + 230, 0.45, cz + 120, 0.3, 260, c=(40, 110, 150), m="Glass", solid=False, refl=0.3)

    # море, Пальма и «парус» на острове
    box((cx, 0.3, -9800), (6400, 0.2, 2000), c=(28, 98, 140), m="Glass", solid=False, refl=0.35)
    pcx, pcz = 4000.0, -9900.0
    SAND = (222, 204, 160)
    box((pcx, 0.5, -9400), (70, 0.6, 1100), c=SAND, m="Sand", solid=False)
    for i in range(14):
        a = math.radians(-70 + i * (140 / 13))
        Lf = 380
        ox, oz = math.sin(a) * Lf / 2, -math.cos(a) * Lf / 2
        box((pcx + ox, 0.5, pcz - 20 + oz), (26, 0.6, Lf), -a, c=SAND, m="Sand", solid=False)
        vx, vz = pcx + ox * 1.6, pcz - 20 + oz * 1.6
        if i % 2 == 0:
            ball((vx, 0.5, vz), 14, c=(60, 120, 60), m="Grass", solid=False)
    for i in range(26):
        t = math.radians(195 + i * (150 / 25))
        Rr = 640
        x, z = pcx + math.cos(t) * Rr, pcz + 40 + math.sin(t) * Rr
        box((x, 0.5, z), (30, 0.6, 2 * math.pi * Rr / 26 * 1.05), -t, c=SAND, m="Sand", solid=False)
    sx, sz = 7400.0, -9150.0
    vcyl(sx, 0, sz, 2, 190, c=SAND, m="Sand", solid=False)
    h_sail = m2s(321)
    wedge((sx, h_sail / 2 + 1, sz), (70, h_sail, 230), (0, math.radians(-30), 0), c=(245, 246, 248), m="SmoothPlastic")
    tilted_cyl((sx + 60, 1, sz - 95), (sx + 20, h_sail + 20, sz - 30), 8, c=(235, 235, 240), m="Metal")
    vcyl(sx - 30, h_sail * 0.62, sz + 70, 2, 40, c=(240, 240, 240), m="Concrete")
    tilted_cyl((cx + 900, 1, -8650), (sx, 2, sz), 18, c=(170, 170, 175), m="Concrete", solid=False)


# ================================================================ ЛОНДОН
def london():
    cx, cz = -4000.0, 12500.0
    half = 1150
    pad(cx, cz, half, c=(140, 142, 140))
    labels.append({"name": "LONDON", "x": cx, "y": 900, "z": cz})

    def zr(x):
        return cz + 120 * math.sin((x - cx) / 480)

    # Темза
    xs = [cx - half + i * (2 * half / 12) for i in range(13)]
    for a, b in zip(xs, xs[1:]):
        za, zb = zr(a), zr(b)
        L = math.hypot(b - a, zb - za)
        box(((a + b) / 2, 0.48, (za + zb) / 2), (L + 6, 0.05, 150), math.atan2(-(zb - za), b - a), c=(58, 92, 102), m="Glass", solid=False, refl=0.3)
    roads(cx, cz, half, 128, 64)

    bigben_x = cx - 760
    eye = (cx - 560, zr(cx - 560) + 175)
    shard = (cx + 320, zr(cx + 320) + 280)
    bridge_x = cx + 700
    zones = [(bigben_x + 230, zr(bigben_x) - 120, 290), (eye[0], eye[1], 170), (shard[0], shard[1], 120),
             (bridge_x, zr(bridge_x), 140), (cx + 520, zr(cx + 520) - 360, 260), (cx - 900, cz + 650, 260)]
    BR = [(150, 75, 60), (170, 95, 70), (225, 215, 190), (200, 195, 180), (140, 140, 145), (185, 120, 90)]
    for gx in range(-8, 9):
        for gz in range(-8, 9):
            x, z = cx + gx * 128, cz + gz * 128
            if abs(z - zr(x)) < 150 or not free(x, z, zones) or rng.random() > 0.86:
                continue
            w, d = R(62, 100), R(62, 100)
            h = R(22, 55)
            col = rng.choice(BR)
            mat = "Brick" if col[0] - col[2] > 60 else "Sandstone" if col[0] > 190 else "Concrete"
            box((x, 0.45 + h / 2, z), (w, h, d), c=col, m=mat)
            rh = min(w, d) * 0.22
            ROOF = (72, 74, 84)
            wedge((x, 0.45 + h + rh / 2, z - d / 4), (w, rh, d / 2), c=ROOF, m="Slate", solid=False)
            wedge((x, 0.45 + h + rh / 2, z + d / 4), (w, rh, d / 2), (0, math.pi, 0), c=ROOF, m="Slate", solid=False)
            if rng.random() < 0.3:
                box((x + w * 0.3, 0.45 + h + rh, z), (4, 10, 4), c=(130, 70, 55), m="Brick", solid=False)
    # Гайд-парк
    box((cx - 900, 0.47, cz + 650), (480, 0.1, 420), c=(92, 140, 70), m="Grass", solid=False)

    # Биг-Бен (96 м) и Вестминстерский дворец
    SAND = (214, 196, 150)
    zb = zr(bigben_x) - 105
    tb = m2s(55)
    box((bigben_x, 0.45 + tb / 2, zb), (24, tb, 24), c=SAND, m="Sandstone")
    yc = 0.45 + tb
    box((bigben_x, yc + 13, zb), (28, 26, 28), c=SAND, m="Sandstone")
    for e in ((0, 0, 0), (0, math.pi / 2, 0)):
        for s in (-1, 1):
            if e[1] == 0:
                add("cyl", (bigben_x, yc + 13, zb + s * 14.2), (0.6, 20, 20), (0, math.pi / 2, 0), c=(245, 240, 220), m="Neon", solid=False)
                box((bigben_x, yc + 16, zb + s * 14.6), (1.2, 8, 0.4), c=(30, 30, 30), solid=False)
            else:
                add("cyl", (bigben_x + s * 14.2, yc + 13, zb), (0.6, 20, 20), c=(245, 240, 220), m="Neon", solid=False)
                box((bigben_x + s * 14.6, yc + 16, zb), (0.4, 8, 1.2), c=(30, 30, 30), solid=False)
    y = yc + 26
    for w_, h_ in ((24, 14), (18, 10), (13, 9), (8, 9), (4, 10), (1.5, 8)):
        box((bigben_x, y + h_ / 2, zb), (w_, h_, w_), c=(70, 90, 80) if w_ < 20 else SAND, m="Slate" if w_ < 20 else "Sandstone")
        y += h_
    px0, px1 = bigben_x + 25, bigben_x + 470
    pz = zr((px0 + px1) / 2) - 100
    box(((px0 + px1) / 2, 0.45 + 22, pz), (px1 - px0, 44, 70), c=SAND, m="Sandstone")
    for i in range(10):
        x = px0 + 20 + i * (px1 - px0 - 40) / 9
        box((x, 0.45 + 52, pz - 34), (5, 16, 5), c=SAND, m="Sandstone", solid=False)
        box((x, 0.45 + 52, pz + 34), (5, 16, 5), c=SAND, m="Sandstone", solid=False)
    wedge(((px0 + px1) / 2, 0.45 + 50, pz - 17), (px1 - px0, 12, 35), c=(70, 74, 84), m="Slate", solid=False)
    wedge(((px0 + px1) / 2, 0.45 + 50, pz + 17), (px1 - px0, 12, 35), (0, math.pi, 0), c=(70, 74, 84), m="Slate", solid=False)
    vt = m2s(98)
    box((px1 + 20, 0.45 + vt / 2, pz), (40, vt, 40), c=SAND, m="Sandstone")

    # Лондонский глаз (135 м)
    ex, ez = eye
    Rr = m2s(60)
    ey = 0.45 + m2s(75)
    n = 36
    for i in range(n):
        t = 2 * math.pi * i / n
        x, yy = ex + Rr * math.cos(t), ey + Rr * math.sin(t)
        add("box", (x, yy, ez), (2 * math.pi * Rr / n * 1.06, 3, 4), (0, 0, t + math.pi / 2), c=(235, 238, 242), m="Metal")
        ell((ex + (Rr + 6) * math.cos(t), ey + (Rr + 6) * math.sin(t), ez), (3, 3.5, 5), c=(200, 225, 240), m="Glass", solid=False, tr=0.2)
    for i in range(16):
        t = 2 * math.pi * i / 16
        add("box", (ex + Rr / 2 * math.cos(t), ey + Rr / 2 * math.sin(t), ez), (Rr, 0.6, 0.6), (0, 0, t), c=(230, 230, 235), m="Metal", solid=False)
    add("cyl", (ex, ey, ez), (14, 12, 12), (0, math.pi / 2, 0), c=(200, 200, 205), m="Metal")
    for s in (-1, 1):
        tilted_cyl((ex + s * 40, 0.45, ez + 70), (ex, ey, ez + 5), 5, c=(225, 228, 232), m="Metal")

    # Осколок (310 м)
    sx, sz = shard
    hs = m2s(306)
    nt = 12
    for i in range(nt):
        k = i / nt
        w_ = 95 * (1 - k) + 4
        box((sx, 0.45 + hs / nt * (i + 0.5), sz), (w_, hs / nt, w_ * 0.85), math.radians(12), c=(190, 210, 225), m="Glass", refl=0.35)
    # Сити: «огурец» и другие башни
    ccx, ccz = cx + 520, zr(cx + 520) - 360
    gh = m2s(180)
    ell((ccx, 0.45 + gh / 2, ccz), (34, gh / 2, 34), c=(55, 95, 110), m="Glass", refl=0.3)
    for i, (dx, dz, h, w) in enumerate(((120, 40, m2s(160), 70), (-110, -60, m2s(230), 60), (40, -160, m2s(200), 55), (-60, 140, m2s(140), 65), (160, -120, m2s(180), 50))):
        glass_tower(ccx + dx, ccz + dz, w, w * 0.8, h, "box" if i % 2 else "setback", rng.choice(GLASS[:3]))

    # Тауэрский мост
    bz = zr(bridge_x)
    STONE = (205, 195, 170)
    for s in (-1, 1):
        z = bz + s * 50
        tt = m2s(65)
        box((bridge_x, 0.45 + tt / 2, z), (28, tt, 28), c=STONE, m="Sandstone")
        for ox in (-11, 11):
            for oz in (-11, 11):
                box((bridge_x + ox, 0.45 + tt + 6, z + oz), (4, 12, 4), c=(60, 70, 80), m="Slate", solid=False)
        wedge((bridge_x, 0.45 + tt + 6, z - 6), (22, 12, 12), c=(60, 70, 80), m="Slate", solid=False)
        wedge((bridge_x, 0.45 + tt + 6, z + 6), (22, 12, 12), (0, math.pi, 0), c=(60, 70, 80), m="Slate", solid=False)
        box((bridge_x, 14, bz + s * 160), (26, 4, 200), c=(110, 150, 190), m="Metal")
    box((bridge_x, 14, bz), (26, 4, 75), c=(110, 150, 190), m="Metal")
    for s in (-1, 1):
        box((bridge_x + s * 9, m2s(44), bz), (6, 6, 100), c=(110, 150, 190), m="Metal")


# ================================================================ ТАШКЕНТ
def tashkent():
    cx, cz = 10500.0, 3000.0
    half = 1050
    pad(cx, cz, half, c=(185, 178, 160))
    roads(cx, cz, half, 135, 67.5)
    labels.append({"name": "TASHKENT", "x": cx, "y": 1000, "z": cz})
    tv = (cx + 600, cz + 520)
    mosque = (cx - 520, cz - 330)
    minor = (cx + 120, cz - 720)
    tcity = (cx + 120, cz + 60)
    chorsu = (cx - 720, cz + 420)
    square = (cx - 180, cz - 30)
    zones = [(tv[0], tv[1], 130), (mosque[0], mosque[1], 200), (minor[0], minor[1], 110), (tcity[0] + 100, tcity[1] + 100, 260),
             (chorsu[0], chorsu[1], 110), (square[0], square[1], 130)]
    PANEL = [(232, 228, 214), (214, 208, 196), (205, 190, 165), (225, 215, 195), (190, 196, 200)]
    for gx in range(-7, 8):
        for gz in range(-7, 8):
            x, z = cx + gx * 135, cz + gz * 135
            if not free(x, z, zones) or rng.random() > 0.84:
                continue
            h = R(26, 58)
            rot = 0.0 if rng.random() < 0.5 else math.pi / 2
            w, d = R(90, 118), 34
            box((x, 0.45 + h / 2, z), (w, h, d), rot, c=rng.choice(PANEL), m="Concrete")
            box((x, 0.45 + h + 1, z), (w * 0.98, 2, d * 0.98), rot, c=(120, 120, 120), m="Concrete", solid=False)
            if rng.random() < 0.35:
                ball((x + (40 if rot == 0 else 0), 0.45 + 7, z + (0 if rot == 0 else 40)), 16, c=(70, 120, 60), m="LeafyGrass", solid=False)

    # Телебашня (375 м): три опоры, ствол, смотровая «тарелка», антенна
    tx, tz = tv
    for j in range(3):
        a = math.radians(90 + j * 120)
        tilted_cyl((tx + 70 * math.cos(a), 0.45, tz + 70 * math.sin(a)), (tx + 9 * math.cos(a), m2s(95), tz + 9 * math.sin(a)), 9, c=(210, 214, 220), m="Metal")
    y = 0.45
    for d, hh in ((24, m2s(100)), (20, m2s(95)), (16, m2s(60))):
        vcyl(tx, y, tz, hh, d, c=(215, 218, 224), m="Metal")
        y += hh
    ell((tx, y, tz), (36, 16, 36), c=(120, 160, 200), m="Glass", refl=0.3)
    ell((tx, y - m2s(40), tz), (22, 8, 22), c=(210, 214, 220), m="Metal")
    for i, (d, hh) in enumerate(((10, m2s(40)), (7, m2s(25)), (5, m2s(20)), (4, m2s(15)), (3, m2s(10)), (2, m2s(10)))):
        vcyl(tx, y, tz, hh, d, c=(220, 40, 40) if i % 2 == 0 else (240, 240, 240), m="SmoothPlastic")
        y += hh
    ball((tx, y + 2, tz), 3, c=(255, 50, 50), m="Neon", solid=False)

    # Медресе с бирюзовыми куполами и минаретами
    mx, mz = mosque
    SAND = (215, 190, 150)
    TURQ = (32, 165, 185)
    W, H = 220, 34
    for s in (-1, 1):
        box((mx, 0.45 + H / 2, mz + s * W / 2), (W, H, 16), c=SAND, m="Sandstone")
        box((mx + s * W / 2, 0.45 + H / 2, mz), (16, H, W), c=SAND, m="Sandstone")
    box((mx, 0.45 + 34, mz + W / 2 + 4), (80, 68, 22), c=SAND, m="Sandstone")
    box((mx, 0.45 + 26, mz + W / 2 + 15.5), (36, 50, 1), c=(30, 70, 130), m="SmoothPlastic", solid=False)
    box((mx, 0.45 + 62, mz + W / 2 + 15.5), (76, 6, 1), c=TURQ, m="SmoothPlastic", solid=False)
    for dx, dz, dd in ((0, -60, 64), (-70, 30, 40), (70, 30, 40)):
        vcyl(mx + dx, 0.45 + H, mz + dz, 18, dd * 0.9, c=SAND, m="Sandstone")
        ell((mx + dx, 0.45 + H + 18, mz + dz), (dd / 2, dd * 0.62, dd / 2), c=TURQ, m="SmoothPlastic", refl=0.15)
        box((mx, 0.45 + H / 2, mz + dz), (W - 30, H, 40), c=SAND, m="Sandstone") if dz == -60 else None
    for sx_ in (-1, 1):
        for sz_ in (-1, 1):
            px, pz = mx + sx_ * (W / 2 + 6), mz + sz_ * (W / 2 + 6)
            vcyl(px, 0.45, pz, 90, 13, c=SAND, m="Sandstone")
            vcyl(px, 0.45 + 70, pz, 6, 15, c=TURQ, m="SmoothPlastic", solid=False)
            vcyl(px, 0.45 + 90, pz, 8, 16, c=SAND, m="Sandstone", solid=False)
            ball((px, 0.45 + 100, pz), 14, c=TURQ, m="SmoothPlastic", solid=False)

    # Белая мечеть с большим голубым куполом
    wx, wz = minor
    box((wx, 0.45 + 18, wz), (90, 36, 90), c=(245, 245, 242), m="Marble")
    vcyl(wx, 0.45 + 36, wz, 14, 56, c=(245, 245, 242), m="Marble")
    ell((wx, 0.45 + 50, wz), (30, 32, 30), c=(70, 150, 210), m="SmoothPlastic", refl=0.2)
    for s in (-1, 1):
        vcyl(wx + s * 62, 0.45, wz + 40, 85, 10, c=(245, 245, 242), m="Marble")
        ball((wx + s * 62, 0.45 + 88, wz + 40), 12, c=(70, 150, 210), m="SmoothPlastic", solid=False)

    # Ташкент-Сити: современные стеклянные башни
    for i, (dx, dz, h, w, shp) in enumerate(((0, 0, m2s(150), 60, "setback"), (110, 30, m2s(120), 55, "box"), (60, 150, m2s(100), 50, "cyl"),
                                              (190, 140, m2s(130), 55, "twist"), (230, 20, m2s(90), 60, "box"), (-60, 120, m2s(85), 45, "cyl"))):
        glass_tower(tcity[0] + dx, tcity[1] + dz, w, w * 0.85, h, shp, rng.choice(GLASS))
    # Чорсу: большой бирюзовый купол рынка
    ell((chorsu[0], 0.45, chorsu[1]), (70, 48, 70), c=TURQ, m="SmoothPlastic", refl=0.1)
    # Сквер с памятником и фонтаном
    vcyl(square[0], 0.45, square[1], 0.4, 230, c=(90, 140, 70), m="Grass", solid=False)
    vcyl(square[0], 0.85, square[1], 0.3, 60, c=(50, 120, 160), m="Glass", solid=False, refl=0.3)
    box((square[0], 0.45 + 6, square[1]), (10, 12, 10), c=(120, 110, 100), m="Granite")
    box((square[0], 0.45 + 16, square[1]), (5, 8, 8), c=(110, 80, 40), m="Metal", solid=False)
    # Гостиница «Узбекистан» — решётчатый фасад
    hx, hz = cx - 180, cz + 220
    box((hx, 0.45 + 45, hz), (150, 90, 32), c=(225, 225, 220), m="Concrete")
    for i in range(12):
        box((hx - 70 + i * 12.7, 0.45 + 45, hz - 16.5), (2, 88, 1), c=(170, 170, 168), m="Concrete", solid=False)


# ================================================================ ГОНКА ЧЕРЕЗ КОЛЬЦА
RING_PATH = [
    (0, 300, -3500, 90, "Старт · Skyport"),
    (2500, 450, -5500, 90, "К Дубаю"),
    (5300, 950, -7500, 90, "Бурдж-Халифа"),
    (7000, 200, -9400, 90, "Отель-«парус»"),
    (4000, 120, -10100, 90, "Пальма"),
    (8000, 600, -2000, 90, "К Ташкенту"),
    (10950, 450, 3520, 90, "Телебашня"),
    (9980, 150, 2900, 90, "Медресе"),
    (3000, 700, 9000, 90, "К Лондону"),
    (-4560, 200, 12390, 90, "Лондонский глаз"),
    (-3300, 50, 12619, 32, "Под Тауэрским мостом", -math.pi / 2),  # вдоль Темзы на восток
    (-1500, 400, 6000, 90, "Домой"),
    (0, 200, 1500, 90, "Финиш · полоса A"),
]


def rings():
    out = []
    n = len(RING_PATH)
    for i, ring in enumerate(RING_PATH):
        x, y, z, r, name = ring[:5]
        a = RING_PATH[max(0, i - 1)]
        b = RING_PATH[min(n - 1, i + 1)]
        dx, dz = b[0] - a[0], b[2] - a[2]
        yaw = ring[5] if len(ring) > 5 else math.atan2(-dx, -dz)  # кольцо смотрит вдоль маршрута
        out.append([x, y, z, r, round(yaw, 4), name])
    return out


def main():
    dubai()
    london()
    tashkent()
    data = {"props": props, "obstacles": obstacles, "pads": pads, "labels": labels, "rings": rings()}
    with open(os.path.join(ROOT, "tools", "cities.json"), "w") as f:
        json.dump(data, f, separators=(",", ":"))

    def lua(v):
        if isinstance(v, str):
            return '"' + v + '"'
        if isinstance(v, float):
            s = repr(round(v, 4))
            return s[:-2] if s.endswith(".0") else s
        return str(v)

    out = ["--!nocheck", "-- СГЕНЕРИРОВАНО tools/gen_cities.py — не правьте вручную.",
           "-- props: {вид, x, y, z, sx, sy, sz, rx, ry, rz, цвет 0xRRGGBB, материал, твёрдое, отражение, прозрачность}",
           "local P = {"]
    for p in props:
        out.append("{" + ",".join(lua(v) for v in p) + "},")
    out.append("}")
    out.append("local O = {")
    for o in obstacles:
        out.append("{" + ",".join(lua(float(v)) for v in o) + "},")
    out.append("}")
    out.append("local PADS = {")
    for p in pads:
        out.append("{" + ",".join(lua(float(v)) for v in p) + "},")
    out.append("}")
    out.append("local LABELS = {")
    for l in labels:
        out.append('{name="%s", x=%s, y=%s, z=%s},' % (l["name"], lua(float(l["x"])), lua(float(l["y"])), lua(float(l["z"]))))
    out.append("}")
    out.append("local RINGS = {")
    for r in data["rings"]:
        out.append('{%s, %s, %s, %s, %s, "%s"},' % (lua(float(r[0])), lua(float(r[1])), lua(float(r[2])), lua(float(r[3])), lua(float(r[4])), r[5]))
    out.append("}")
    out.append("return { props = P, obstacles = O, pads = PADS, labels = LABELS, rings = RINGS }")
    with open(os.path.join(ROOT, "src", "shared", "CityData.luau"), "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"props={len(props)} obstacles={len(obstacles)} pads={len(pads)}")


if __name__ == "__main__":
    main()
