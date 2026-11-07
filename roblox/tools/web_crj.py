# Bombardier CRJ900 (веб): региональный джет — двигатели в хвосте, Т-оперение, 90 пассажиров (тот же конфиг — PlaneConfigs.luau).
# Плюс Boeing 777: шестиколёсные тележки основных стоек (три пары колёс подряд), как у настоящего.
CRJ_CFG = """PLANES.CRJ900 = { name: "Bombardier CRJ900", cls: "Региональный джет", length: 129, diameter: 9.6, span: 89, chord: 12, wing: "low", wingPos: 0.55, sweep: 26, dihedral: 3, engines: "tail2", engineD: 4.2, engineLen: 12, tail: "T", hstabSpan: 30, finHeight: 18, finSweep: 42, gearLen: 4, windows: true, winglets: true, pax: 90, thrust: 6.3, maxKts: 470, stallKts: 112, vrKts: 135, flapMaxKts: 230, pitchRate: 0.48, rollRate: 1.05, yawRate: 0.28, turnBoost: 2.1, groundSteer: 0.55, brakeDecel: 8, stallSink: 50, maxRotate: 12, ceilingFt: 41000, maxTouchdownFpm: 1150, colors: { body: 0xf3f5f8, accent: 0x0f7a8a, tail: 0x0b5560, engine: 0xf3f5f8 } };
"""

def add_crj(s, patch):
    s = patch(s, 'const ORDER = ["C172", "ATR72", "LEAR75"', CRJ_CFG + 'const ORDER = ["C172", "ATR72", "LEAR75", "CRJ900"')
    s = patch(s, '"G650", "GL7500", "LEAR75"', '"G650", "GL7500", "CRJ900", "LEAR75"')
    s = patch(s, 'if (c.id === "F16") return 0; if (c.engines === "prop") return 3;', 'if (c.pax) return c.pax; if (c.id === "F16") return 0; if (c.engines === "prop") return 3;')
    s = patch(s, 'Авиасимулятор · 15 самолётов', 'Авиасимулятор · 16 самолётов')
    s = patch(s, 'Все 15 самолётов в ангаре', 'Все 16 самолётов в ангаре')
    # 777: тележки 2 × 3
    s = patch(s, 'leg(-mainX, mainZ, tp ? 1 : 2, big || tp ? 2 : 1), leg(mainX, mainZ, tp ? 1 : 2, big || tp ? 2 : 1)',
              'leg(-mainX, mainZ, tp ? 1 : 2, cfg.id === "B777" ? 3 : big || tp ? 2 : 1), leg(mainX, mainZ, tp ? 1 : 2, cfg.id === "B777" ? 3 : big || tp ? 2 : 1)')
    s = patch(s, 'if (along > 1) { const bg = add(gear, new THREE.BoxGeometry(wD * 0.2, wD * 0.2, wD * 1.3), strutMat);',
              'if (along > 1) { const bg = add(gear, new THREE.BoxGeometry(wD * 0.2, wD * 0.2, wD * (1.15 * (along - 1) + 0.2)), strutMat);')
    return s
