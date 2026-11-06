# ATR 72-600 (веб): турбовинтовой региональный — высокоплан, Т-оперение, две мотогондолы под крылом
# с шестилопастными винтами, основные стойки из обтекателей по бокам фюзеляжа. Тот же конфиг — в PlaneConfigs.luau.
ATR_CFG = """PLANES.ATR72 = { name: "ATR 72-600", cls: "Турбовинтовой региональный", length: 97, diameter: 9.5, span: 97, chord: 8.5, wing: "high", wingPos: 0.47, sweep: 0, dihedral: 1.5, engines: "turboprop2", engineD: 4.2, engineLen: 15, tail: "T", hstabSpan: 27, finHeight: 16, finSweep: 32, gearLen: 3, windows: true, thrust: 5.4, maxKts: 280, stallKts: 85, vrKts: 102, flapMaxKts: 180, pitchRate: 0.55, rollRate: 1.1, yawRate: 0.3, turnBoost: 2.2, groundSteer: 0.6, brakeDecel: 7, stallSink: 40, maxRotate: 12, ceilingFt: 25000, maxTouchdownFpm: 1150, colors: { body: 0xf3f5f8, accent: 0x1f5fbf, tail: 0x1f5fbf, engine: 0xf3f5f8 } };
"""

TURBOPROP_JS = r"""  } else if (cfg.engines === "turboprop2") {
    // турбовинтовые: гондолы под высоким крылом, шестилопастные винты (вращаются в анимации), выхлоп сбоку
    const props = [], spinM = std(0xe7e9ec, { metal: 0.5, rough: 0.3 });
    for (const s of [-1, 1]) {
      const le = wings[s].rootLE.clone().addScaledVector(wings[s].spanVec, 0.3);
      const p = le.clone().add(new V3(0, -eD * 0.45, eL * 0.1));
      const ng = new THREE.SphereGeometry(1, 24, 14); ng.scale(eD * 0.5, eD * 0.6, eL * 0.55); add(body, ng, engMat, true).position.copy(p);
      const ex = add(body, new THREE.CylinderGeometry(eD * 0.12, eD * 0.15, eD * 0.5, 10).rotateX(Math.PI / 2), darkMat); ex.position.copy(p).add(new V3(s * eD * 0.45, -eD * 0.1, eL * 0.05));
      const pr = new THREE.Group(); pr.position.copy(p).add(new V3(0, 0, -eL * 0.5 - 0.25)); body.add(pr);
      add(pr, new THREE.ConeGeometry(eD * 0.3, eD * 0.7, 18).rotateX(-Math.PI / 2), spinM, true).position.z = -eD * 0.2;
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2, bl = add(pr, new THREE.BoxGeometry(eD * 0.16, eD * 1.55, 0.2), darkMat, true); bl.position.set(Math.cos(a) * eD * 0.82, Math.sin(a) * eD * 0.82, 0); bl.rotation.z = a - Math.PI / 2; bl.rotateY(0.35); }
      const disc = new THREE.Mesh(new THREE.CircleGeometry(eD * 1.65, 32), new THREE.MeshBasicMaterial({ color: 0x222222, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide })); pr.add(disc);
      props.push({ g: pr, disc }); engines.push(p.clone().add(new V3(0, 0, eL * 0.5)));
    }
    root.userData.props = props;
  } else if (cfg.engines === "prop") {"""

def add_atr(s, patch):
    s = patch(s, 'const ORDER = ["C172", "LEAR75"', ATR_CFG + 'const ORDER = ["C172", "ATR72", "LEAR75"')
    s = patch(s, '["CESSNA", ["C172"]]', '["ATR · ТУРБОВИНТОВЫЕ", ["ATR72"]], ["CESSNA", ["C172"]]')
    s = patch(s, '  } else if (cfg.engines === "prop") {', TURBOPROP_JS)
    s = patch(s, '      if (u.prop) { u.prop.rotation.z', '      if (u.props) for (const q of u.props) { q.g.rotation.z += dt * (10 + f.throttle * 60); q.disc.material.opacity = Math.min(0.22, 0.04 + f.throttle * 0.25); }\n      if (u.prop) { u.prop.rotation.z')
    # стойки высокоплана — из фюзеляжа (раньше тянулись от крыла), у ATR — узкая колея и обтекатели по бокам
    s = patch(s, 'const top = Math.abs(x) > Rr * 0.6 ? wingY', 'const top = Math.abs(x) > Rr * 0.6 && cfg.wing !== "high" ? wingY')
    s = patch(s, 'mainY = Math.abs(mainX) > Rr * 0.6 ? wingY', 'mainY = Math.abs(mainX) > Rr * 0.6 && cfg.wing !== "high" ? wingY')
    s = patch(s, 'bayY = Math.abs(mainX) > Rr * 0.6 ? wingY', 'bayY = Math.abs(mainX) > Rr * 0.6 && cfg.wing !== "high" ? wingY')
    s = patch(s, 'const big = L > 200, mainX = Math.max(Rr * 0.6, S * 0.06)', 'const big = L > 200, tp = cfg.engines === "turboprop2", mainX = tp ? Rr * 0.84 : Math.max(Rr * 0.6, S * 0.06)')
    s = patch(s, 'mainGear.push(leg(-mainX, mainZ, 2, big ? 2 : 1), leg(mainX, mainZ, 2, big ? 2 : 1));',
              'mainGear.push(leg(-mainX, mainZ, tp ? 1 : 2, big || tp ? 2 : 1), leg(mainX, mainZ, tp ? 1 : 2, big || tp ? 2 : 1));\n'
              '  if (tp) for (const s of [-1, 1]) { const sg = new THREE.SphereGeometry(1, 20, 12); sg.scale(Rr * 0.4, Rr * 0.34, L * 0.09); add(body, sg, std(col.body, { metal: 0.2, rough: 0.35 }), true).position.set(s * Rr * 0.88, -Rr * 0.72, mainZ); }')
    s = patch(s, 'if (c.id === "F16") return 0; if (c.engines === "prop") return 3;', 'if (c.id === "F16") return 0; if (c.engines === "prop") return 3; if (c.engines === "turboprop2") return 70;')
    s = patch(s, 'Авиасимулятор · 14 самолётов', 'Авиасимулятор · 15 самолётов')
    s = patch(s, 'Все 14 самолётов в ангаре', 'Все 15 самолётов в ангаре')
    return s
