# Airbus A340-600 (веб; тот же конфиг — PlaneConfigs.luau) и шесть новых ливрей (цвета без логотипов и названий авиакомпаний).
A340 = """PLANES.A340 = { name: "Airbus A340-600", cls: "Четырёхмоторный дальнемагистральный", length: 269, diameter: 20, span: 227, chord: 33, wing: "low", wingPos: 0.46, sweep: 30, dihedral: 6, engines: "wing4", engineD: 9, engineLen: 18, tail: "conventional", hstabSpan: 74, finHeight: 46, finSweep: 40, gearLen: 7.5, windows: true, winglets: true, thrust: 5.2, maxKts: 480, stallKts: 135, vrKts: 160, flapMaxKts: 230, pitchRate: 0.3, rollRate: 0.66, yawRate: 0.18, turnBoost: 2, groundSteer: 0.42, brakeDecel: 8, stallSink: 64, maxRotate: 11, ceilingFt: 41000, maxTouchdownFpm: 1250, colors: { body: 0xf3f5f8, accent: 0x7a1f3d, tail: 0x5a1530, engine: 0xc4c8ce } };
"""
LIV = '''["royal", "Королевский синий", [0xf4f5f7, 0x1c2c6b, 0x1c2c6b, 0xc8ccd3]], ["sakura", "Сакура", [0xfbf8f9, 0xe07a9b, 0xc74f78, 0xf1e4ea]], ["aurora", "Северное сияние", [0xf4f7f8, 0x1fb5a3, 0x5a3fa8, 0xe6ecef]], ["retro", "Ретро 70-х", [0xf5f1e8, 0xd96b1f, 0x7a3b1c, 0xe8e0d0]], ["emerald", "Изумрудный", [0xf3f6f4, 0x0f7a4a, 0x0b5a36, 0xdfe8e2]], ["arctic", "Арктика", [0xffffff, 0x7fc4e8, 0x4a9cd0, 0xf0f5f8]]'''

def add_a340(s, patch):
    s = patch(s, 'const ORDER = ["C172"', A340 + 'const ORDER = ["C172"')
    s = patch(s, '"B787", "A330", "A350", "B777"', '"B787", "A330", "A340", "A350", "B777"')
    s = patch(s, '["A220", "A320", "A330", "A350", "A380"]', '["A220", "A320", "A330", "A340", "A350", "A380"]')
    s = patch(s, '["graphite", "Ночной графит", [0x2b2f36, 0xff7a1a, 0x1c1f24, 0x3a3f47]]];', '["graphite", "Ночной графит", [0x2b2f36, 0xff7a1a, 0x1c1f24, 0x3a3f47]], ' + LIV + '];')
    s = patch(s, 'Авиасимулятор · 16 самолётов', 'Авиасимулятор · 17 самолётов')
    s = patch(s, 'Все 16 самолётов в ангаре', 'Все 17 самолётов в ангаре')
    return s
