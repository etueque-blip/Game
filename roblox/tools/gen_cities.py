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


def street_trees(cx, cz, half, step, offset, kind, zones, skip=None, avenues=3, spacing=80, side=11):
    """Деревья вдоль главных улиц: пальмы (Дубай), чинары (Ташкент), лиственные (Лондон).
    Декоративные: пролетаются насквозь, не ставятся в здания, реки и у достопримечательностей."""
    n = int(half * 2 // step)
    lines = [-half + offset + i * step for i in range(n + 1) if abs(-half + offset + i * step) <= half]
    if not lines:
        return
    pick = [lines[int(len(lines) * (k + 0.5) / avenues)] for k in range(avenues)]
    def blocked(x, z):
        if not free(x, z, zones) or (skip and skip(x, z)):
            return True
        for o in obstacles:
            if o[0] - 7 < x < o[3] + 7 and o[2] - 7 < z < o[5] + 7:
                return True
        return False
    def tree(x, z):
        if blocked(x, z):
            return
        if kind == "palm":
            h = R(13, 19)
            vcyl(x, 0.45, z, h, 1.5, c=(120, 92, 60), m="Wood", solid=False)
            ell((x, 0.45 + h, z), (6.5, 2.2, 6.5), c=(62, 120, 58), m="LeafyGrass", solid=False)
        elif kind == "plane":
            vcyl(x, 0.45, z, 6, 1.6, c=(96, 76, 54), m="Wood", solid=False)
            ball((x, 0.45 + 10, z), R(10, 13), c=rng.choice([(70, 125, 60), (82, 138, 66), (60, 112, 52)]), m="LeafyGrass", solid=False)
        else:
            vcyl(x, 0.45, z, 5, 1.4, c=(90, 72, 52), m="Wood", solid=False)
            ball((x, 0.45 + 8.5, z), R(8, 10), c=rng.choice([(64, 110, 56), (76, 122, 60)]), m="LeafyGrass", solid=False)
    for t in pick:
        k = -half + 20
        while k < half - 20:
            for sd in (-side, side):
                tree(cx + t + sd, cz + k)   # вдоль улиц север-юг
                tree(cx + k, cz + t + sd)   # вдоль улиц запад-восток
            k += spacing


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
    frame = (cx - 720, cz + 640)
    zones = [(cx, cz, 240), (frame[0], frame[1], 150)]
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
    # Дубайская рамка (150 м): две башни и перемычка, золотой фасад
    fx, fz = frame
    fh, fw = m2s(150), m2s(93)
    GOLD = (214, 176, 72)
    for s_ in (-1, 1):
        box((fx + s_ * fw / 2, 0.45 + fh / 2, fz), (24, fh, 26), c=GOLD, m="Metal", refl=0.2)
    box((fx, 0.45 + fh - 12, fz), (fw + 24, 24, 26), c=GOLD, m="Metal", refl=0.2)
    box((fx, 0.45 + fh - 12, fz), (fw - 10, 14, 27), c=(120, 170, 200), m="Glass", solid=False, refl=0.3)
    box((fx, 0.45 + 2, fz), (fw + 60, 4, 80), c=(200, 190, 170), m="Concrete", solid=False)
    # фонтан и пруд у основания
    vcyl(cx + 230, 0.45, cz + 120, 0.3, 260, c=(40, 110, 150), m="Glass", solid=False, refl=0.3)

    street_trees(cx, cz, half, 145, 72.5, "palm", zones + [(cx, cz, 300)])

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
    stpaul = (cx + 60, zr(cx + 60) - 330)
    zones = [(bigben_x + 230, zr(bigben_x) - 120, 290), (eye[0], eye[1], 170), (shard[0], shard[1], 120), (stpaul[0], stpaul[1], 130),
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

    street_trees(cx, cz, half, 128, 64, "leaf", zones, skip=lambda x, z: abs(z - zr(x)) < 95, side=9)
    # деревья Гайд-парка
    for _ in range(70):
        street_x, street_z = cx - 900 + R(-220, 220), cz + 650 + R(-190, 190)
        vcyl(street_x, 0.45, street_z, 5, 1.4, c=(90, 72, 52), m="Wood", solid=False)
        ball((street_x, 0.45 + 8.5, street_z), R(9, 13), c=rng.choice([(64, 110, 56), (76, 122, 60), (58, 100, 50)]), m="LeafyGrass", solid=False)

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

    # Собор Святого Павла (111 м): неф, барабан, купол, фонарь, две башни фасада
    px_, pz_ = stpaul
    STONE2 = (222, 214, 192)
    box((px_, 0.45 + 22, pz_), (170, 44, 56), c=STONE2, m="Limestone")
    box((px_ + 20, 0.45 + 18, pz_), (50, 36, 120), c=STONE2, m="Limestone")
    vcyl(px_ + 20, 0.45 + 44, pz_, 34, 66, c=STONE2, m="Limestone")
    vcyl(px_ + 20, 0.45 + 78, pz_, 6, 70, c=(200, 192, 170), m="Limestone", solid=False)
    ell((px_ + 20, 0.45 + 84, pz_), (31, 40, 31), c=(150, 160, 160), m="Slate")
    vcyl(px_ + 20, 0.45 + 122, pz_, 22, 10, c=STONE2, m="Limestone")
    ball((px_ + 20, 0.45 + 147, pz_), 7, c=(220, 180, 60), m="Metal", solid=False)
    vcyl(px_ + 20, 0.45 + 150, pz_, 14, 1.6, c=(220, 180, 60), m="Metal", solid=False)
    for s_ in (-1, 1):
        box((px_ - 78, 0.45 + 40, pz_ + s_ * 20), (16, 80, 16), c=STONE2, m="Limestone")
        box((px_ - 78, 0.45 + 86, pz_ + s_ * 20), (10, 12, 10), c=(150, 160, 160), m="Slate", solid=False)
    box((px_ - 92, 0.45 + 18, pz_), (14, 36, 44), c=STONE2, m="Limestone")

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
    museum = (cx + 380, cz - 330)
    zones = [(tv[0], tv[1], 130), (mosque[0], mosque[1], 200), (minor[0], minor[1], 110), (tcity[0] + 100, tcity[1] + 100, 260),
             (chorsu[0], chorsu[1], 110), (square[0], square[1], 130), (museum[0], museum[1], 95)]
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
    # Музей с бирюзовым ребристым куполом: круглый барабан, колоннада, купол из «долек»
    mx_, mz_ = museum
    WHITE = (238, 236, 228)
    vcyl(mx_, 0.45, mz_, 4, 118, c=(200, 195, 185), m="Granite")
    vcyl(mx_, 4.45, mz_, 34, 92, c=WHITE, m="Marble")
    for i in range(16):
        a = 2 * math.pi * i / 16
        vcyl(mx_ + math.cos(a) * 52, 4.45, mz_ + math.sin(a) * 52, 34, 4, c=WHITE, m="Marble", solid=False)
    vcyl(mx_, 38.45, mz_, 4, 112, c=WHITE, m="Marble")
    ell((mx_, 42.45, mz_), (46, 40, 46), c=(40, 150, 190), m="SmoothPlastic", refl=0.15)
    for i in range(12):
        a = 2 * math.pi * i / 12
        add("box", (mx_ + math.cos(a) * 30, 72, mz_ + math.sin(a) * 30), (1.5, 22, 1.5), (0, -a, math.radians(48) * 0), c=(220, 200, 120), m="Metal", solid=False)
    vcyl(mx_, 82, mz_, 10, 4, c=(220, 190, 90), m="Metal", solid=False)
    ball((mx_, 93, mz_), 5, c=(220, 190, 90), m="Metal", solid=False)

    street_trees(cx, cz, half, 135, 67.5, "plane", zones)

    # Гостиница «Узбекистан» — решётчатый фасад
    hx, hz = cx - 180, cz + 220
    box((hx, 0.45 + 45, hz), (150, 90, 32), c=(225, 225, 220), m="Concrete")
    for i in range(12):
        box((hx - 70 + i * 12.7, 0.45 + 45, hz - 16.5), (2, 88, 1), c=(170, 170, 168), m="Concrete", solid=False)


# ================================================================ СТАМБУЛ (Турция)
def istanbul():
    cx, cz = -20500.0, 20500.0
    half = 1150
    pad(cx, cz, half, c=(176, 170, 158))
    labels.append({"name": "ISTANBUL", "x": cx, "y": 900, "z": cz})
    # пролив Босфор с севера на юг через город
    box((cx + 150, 0.48, cz), (230, 0.05, 2 * half), c=(40, 96, 128), m="Glass", solid=False, refl=0.35)
    roads(cx, cz, half, 130, 65)
    sofia, blue, galata = (cx - 520, cz + 300), (cx - 520, cz - 260), (cx + 600, cz - 420)
    zones = [(sofia[0], sofia[1], 190), (blue[0], blue[1], 210), (galata[0], galata[1], 80), (cx + 150, cz, 170)]
    ROOF = (176, 74, 52)
    for gx in range(-8, 9):
        for gz in range(-8, 9):
            x, z = cx + gx * 130, cz + gz * 130
            if abs(x - (cx + 150)) < 190 or not free(x, z, zones) or rng.random() > 0.85:
                continue
            w, d, h = R(55, 95), R(55, 95), R(18, 45)
            box((x, 0.45 + h / 2, z), (w, h, d), c=rng.choice([(232, 222, 200), (220, 205, 180), (240, 236, 226), (210, 190, 160)]), m="Plaster")
            rh = min(w, d) * 0.2
            wedge((x, 0.45 + h + rh / 2, z - d / 4), (w, rh, d / 2), c=ROOF, m="Brick", solid=False)
            wedge((x, 0.45 + h + rh / 2, z + d / 4), (w, rh, d / 2), (0, math.pi, 0), c=ROOF, m="Brick", solid=False)
    # современные башни на восточном берегу
    for dx, dz, hh in ((520, 520, m2s(180)), (640, 380, m2s(150)), (420, 640, m2s(130))):
        glass_tower(cx + dx, cz + dz, 60, 55, hh, "setback", rng.choice(GLASS))
    PINK = (214, 170, 140)
    def mosque(mx, mz, dome_d, minarets, cascade):
        box((mx, 0.45 + 22, mz), (dome_d * 2.2, 44, dome_d * 2.2), c=PINK, m="Sandstone")
        vcyl(mx, 0.45 + 44, mz, 14, dome_d * 1.2, c=PINK, m="Sandstone")
        ell((mx, 0.45 + 58, mz), (dome_d * 0.6, dome_d * 0.42, dome_d * 0.6), c=(120, 132, 140), m="Slate")
        vcyl(mx, 0.45 + 58 + dome_d * 0.42, mz, 10, 3, c=(220, 190, 90), m="Metal", solid=False)
        if cascade:
            for sx_ in (-1, 1):
                for sz_ in (-1, 1):
                    ell((mx + sx_ * dome_d * 0.75, 0.45 + 44, mz + sz_ * dome_d * 0.75), (dome_d * 0.3, dome_d * 0.22, dome_d * 0.3), c=(120, 132, 140), m="Slate", solid=False)
        for i in range(minarets):
            a = 2 * math.pi * i / minarets + math.pi / 4
            px, pz = mx + math.cos(a) * dome_d * 1.45, mz + math.sin(a) * dome_d * 1.45
            vcyl(px, 0.45, pz, 110, 6, c=(236, 232, 222), m="Marble")
            vcyl(px, 0.45 + 80, pz, 3, 9, c=(236, 232, 222), m="Marble", solid=False)
            wedge((px, 0.45 + 110 + 9, pz - 1.5), (6, 18, 3), c=(120, 132, 140), m="Slate", solid=False)
            wedge((px, 0.45 + 110 + 9, pz + 1.5), (6, 18, 3), (0, math.pi, 0), c=(120, 132, 140), m="Slate", solid=False)
    mosque(sofia[0], sofia[1], 64, 4, False)   # Айя-София: огромный купол, 4 минарета
    mosque(blue[0], blue[1], 52, 6, True)      # Голубая мечеть: каскад куполов, 6 минаретов
    # Галатская башня (67 м): каменный цилиндр с коническим верхом
    gx_, gz_ = galata
    vcyl(gx_, 0.45, gz_, m2s(52), 30, c=(196, 178, 150), m="Cobblestone")
    vcyl(gx_, 0.45 + m2s(52), gz_, 6, 34, c=(196, 178, 150), m="Cobblestone")
    for k, (w_, h_) in enumerate(((28, 10), (20, 10), (12, 10), (4, 8))):
        box((gx_, 0.45 + m2s(52) + 6 + k * 10 + h_ / 2, gz_), (w_, h_, w_), math.radians(45), c=(80, 90, 100), m="Slate", solid=False)
    # Босфорский мост: два пилона, настил, тросы
    bz = cz + 900
    for sx_ in (-1, 1):
        box((cx + 150 + sx_ * 170, 0.45 + m2s(82), bz), (8, m2s(165), 22), c=(200, 205, 210), m="Metal")
    box((cx + 150, 30, bz), (520, 4, 26), c=(150, 155, 160), m="Concrete")
    for sz_ in (-11, 11):
        tilted_cyl((cx + 150 - 170, m2s(165), bz + sz_), (cx + 150, 40, bz + sz_), 1.2, c=(230, 230, 235), m="Metal", solid=False)
        tilted_cyl((cx + 150 + 170, m2s(165), bz + sz_), (cx + 150, 40, bz + sz_), 1.2, c=(230, 230, 235), m="Metal", solid=False)
    street_trees(cx, cz, half, 130, 65, "leaf", zones, skip=lambda x, z: abs(x - (cx + 150)) < 140, avenues=2)


# ================================================================ ЭР-РИЯД (Саудовская Аравия)
def riyadh():
    cx, cz = 21000.0, 20500.0
    half = 1150
    pad(cx, cz, half, c=(214, 196, 160))
    roads(cx, cz, half, 145, 72.5)
    labels.append({"name": "RIYADH", "x": cx, "y": 1100, "z": cz})
    kingdom, faisal = (cx - 150, cz - 150), (cx + 380, cz + 300)
    zones = [(kingdom[0], kingdom[1], 170), (faisal[0], faisal[1], 140)]
    SAND = [(222, 204, 170), (210, 190, 152), (232, 218, 190), (196, 176, 140)]
    for gx in range(-7, 8):
        for gz in range(-7, 8):
            x, z = cx + gx * 145, cz + gz * 145
            if not free(x, z, zones) or rng.random() > 0.8:
                continue
            dist = math.hypot(gx, gz)
            if dist < 3 and rng.random() < 0.5:
                glass_tower(x, z, R(50, 80), R(50, 80), R(150, 380), rng.choice(["box", "setback", "cyl"]), rng.choice(GLASS))
            else:
                h = R(20, 60)
                box((x, 0.45 + h / 2, z), (R(70, 110), h, R(70, 110)), c=rng.choice(SAND), m="Sandstone")
    # Kingdom Centre (302 м): два сужающихся крыла и «мост» под проёмом
    kx, kz = kingdom
    H = m2s(302)
    for i in range(14):
        k = i / 14
        y0, hh = 0.45 + H * 0.78 * k, H * 0.78 / 14
        w_ = 95 * (1 - k * 0.55)
        box((kx, y0 + hh / 2, kz), (w_, hh, 52 * (1 - k * 0.3)), c=(150, 175, 195), m="Glass", refl=0.35)
    for sx_ in (-1, 1):
        for i in range(6):
            k = i / 6
            hh = H * 0.22 / 6
            box((kx + sx_ * (22 + k * 10), 0.45 + H * 0.78 + hh * (i + 0.5), kz), (14 * (1 - k * 0.6), hh, 34), math.radians(sx_ * 8), c=(150, 175, 195), m="Glass", refl=0.35)
    box((kx, 0.45 + H * 0.86, kz), (70, 5, 18), c=(200, 205, 215), m="Metal")
    # Al Faisaliah (267 м): четырёхгранная «игла» с золотым шаром
    fx, fz = faisal
    H2 = m2s(267)
    for i in range(12):
        k = i / 12
        w_ = 70 * (1 - k) + 6
        box((fx, 0.45 + H2 * 0.85 / 12 * (i + 0.5), fz), (w_, H2 * 0.85 / 12, w_), math.radians(45), c=(170, 190, 200), m="Glass", refl=0.3)
    ball((fx, 0.45 + H2 * 0.78, fz), 28, c=(220, 180, 70), m="Metal", refl=0.3)
    vcyl(fx, 0.45 + H2 * 0.85, fz, H2 * 0.15, 3, c=(220, 220, 225), m="Metal")
    street_trees(cx, cz, half, 145, 72.5, "palm", zones)


# ================================================================ САМАРКАНД (Узбекистан)
def samarkand():
    cx, cz = -21000.0, -20500.0
    half = 1050
    pad(cx, cz, half, c=(196, 180, 150))
    roads(cx, cz, half, 135, 67.5)
    labels.append({"name": "SAMARKAND", "x": cx, "y": 800, "z": cz})
    registan, gur = (cx, cz), (cx + 520, cz + 420)
    zones = [(registan[0], registan[1], 330), (gur[0], gur[1], 120)]
    for gx in range(-7, 8):
        for gz in range(-7, 8):
            x, z = cx + gx * 135, cz + gz * 135
            if not free(x, z, zones) or rng.random() > 0.82:
                continue
            h = R(14, 34)
            box((x, 0.45 + h / 2, z), (R(60, 100), h, R(60, 100)), c=rng.choice([(214, 196, 160), (200, 180, 146), (226, 212, 186)]), m="Sandstone")
    SAND = (206, 178, 132)
    TURQ = (32, 165, 185)
    BLUE = (30, 70, 140)
    # Регистан: три медресе вокруг площади (запад, север, восток), у каждого портал, купола, минареты
    rx, rz = registan
    box((rx, 0.47, rz), (260, 0.1, 260), c=(190, 170, 130), m="Cobblestone", solid=False)
    for name, ox, oz, face in (("Улугбек", -200, 0, 0), ("Тилля-Кари", 0, -200, 1), ("Шердор", 200, 0, 2)):
        mx, mz = rx + ox, rz + oz
        along_x = face == 1
        w, dpt = (220, 90) if along_x else (90, 220)
        box((mx, 0.45 + 22, mz), (w, 44, dpt), c=SAND, m="Sandstone")
        # портал (пештак) к площади
        px = mx + (0 if along_x else (40 if face == 0 else -40))
        pz = mz + (40 if along_x else 0)
        ps = (70, 70, 22) if along_x else (22, 70, 70)
        box((px, 0.45 + 35, pz), ps, c=SAND, m="Sandstone")
        arch = (34, 50, 1) if along_x else (1, 50, 34)
        apos = (px, 0.45 + 28, pz + 11.5) if along_x else (px + (11.5 if face == 0 else -11.5), 0.45 + 28, pz)
        box(apos, arch, c=BLUE, m="SmoothPlastic", solid=False)
        # бирюзовые купола и угловые минареты
        for k in (-1, 1):
            dxx, dzz = (k * 70, -20) if along_x else ((20 if face == 2 else -20), k * 70)
            vcyl(mx + dxx, 0.45 + 44, mz + dzz, 12, 34, c=SAND, m="Sandstone")
            ell((mx + dxx, 0.45 + 56, mz + dzz), (18, 22, 18), c=TURQ, m="SmoothPlastic", refl=0.15)
            mx2, mz2 = (mx + k * 108, mz + 42) if along_x else (mx + (42 if face == 0 else -42), mz + k * 108)
            vcyl(mx2, 0.45, mz2, 88, 12, c=SAND, m="Sandstone")
            vcyl(mx2, 0.45 + 60, mz2, 6, 14, c=TURQ, m="SmoothPlastic", solid=False)
            ball((mx2, 0.45 + 92, mz2), 12, c=TURQ, m="SmoothPlastic", solid=False)
    # Гур-Эмир: восьмигранный барабан и ребристый бирюзовый купол
    gx_, gz_ = gur
    box((gx_, 0.45 + 20, gz_), (90, 40, 90), c=SAND, m="Sandstone")
    vcyl(gx_, 0.45 + 40, gz_, 28, 52, c=SAND, m="Sandstone")
    ell((gx_, 0.45 + 70, gz_), (32, 38, 32), c=TURQ, m="SmoothPlastic", refl=0.15)
    for i in range(16):
        a = 2 * math.pi * i / 16
        add("box", (gx_ + math.cos(a) * 30.5, 0.45 + 82, gz_ + math.sin(a) * 30.5), (1.6, 30, 1.6), (0, -a, 0), c=(20, 120, 150), m="SmoothPlastic", solid=False)
    vcyl(gx_, 0.45 + 108, gz_, 10, 3, c=(220, 190, 90), m="Metal", solid=False)
    for sx_ in (-1, 1):
        vcyl(gx_ + sx_ * 60, 0.45, gz_ - 50, 70, 10, c=SAND, m="Sandstone")
    street_trees(cx, cz, half, 135, 67.5, "plane", zones, avenues=2)


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
    istanbul()
    riyadh()
    samarkand()
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
