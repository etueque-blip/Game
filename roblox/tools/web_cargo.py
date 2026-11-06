# Грузовой терминал (веб) во всех аэропортах: склад 200 × 260 с восемью доками и вывеской CARGO,
# бетонная площадка, ряды авиаконтейнеров (в два яруса), тягач с тележками, погрузчик-платформа.
# Те же места — в src/server/WorldBuilder.luau и World.luau (площадка и препятствие).
CARGO_JS = r"""  // грузовой терминал
  { const CX = W / 2 + 1010, CZ = 1260, wallM = std(0xd9dde2, { rough: 0.6 }), roofM = std(0x6b7480, { metal: 0.6, rough: 0.4 }), dockM = std(0x2b3038, { rough: 0.6 }), yelM = std(0xf2be28, { rough: 0.5 });
    box(430, 0.2, 520, std(0xa5a5a0, { rough: 0.9 }), W / 2 + 915, 0.53, CZ);
    box(200, 30, 260, wallM, CX, 15, CZ, true); box(204, 2, 264, roofM, CX, 31, CZ, true);
    for (let k = 0; k < 8; k++) { const z = CZ - 105 + k * 30; box(1, 14, 22, dockM, CX - 100.6, 7.5, z); box(1.2, 2, 24, yelM, CX - 100.8, 15.5, z); box(6, 1.2, 22, std(0x50565e, { rough: 0.8 }), CX - 103, 1.2, z); }
    const sg = new THREE.Mesh(new THREE.PlaneGeometry(90, 11), new THREE.MeshBasicMaterial({ map: canvasTex(512, 64, (x) => { x.fillStyle = "#1f4f9a"; x.fillRect(0, 0, 512, 64); x.fillStyle = "#fff"; x.font = "900 46px Arial"; x.textAlign = "center"; x.textBaseline = "middle"; x.fillText("CARGO TERMINAL", 256, 34); }) }));
    sg.position.set(CX - 101, 24, CZ); sg.rotation.y = -Math.PI / 2; grp.add(sg);
    // ряды контейнеров
    const uldM = [std(0xc4c9cf, { metal: 0.7, rough: 0.35 }), std(0x2f5fa8, { rough: 0.6 }), std(0xd46a2a, { rough: 0.6 }), std(0x9aa0a8, { metal: 0.6, rough: 0.4 })], baseM = std(0x30343a, { rough: 0.7 });
    let n = 0; for (let r = 0; r < 4; r++) for (let k = 0; k < 9; k++) { const x = W / 2 + 735 + r * 30, z = CZ - 170 + k * 14; if ((r * 9 + k) % 7 === 3) continue;
      const tiers = (r + k) % 3 === 0 ? 2 : 1; for (let t = 0; t < tiers; t++) { box(9, 0.6, 9, baseM, x, 0.9 + t * 8.2, z); box(9, 7.4, 9, uldM[(n++) % 4], x, 4.9 + t * 8.2, z, true); } }
    // тягач с тележками
    const tz = CZ + 120, tx0 = W / 2 + 760; box(8, 3, 5, yelM, tx0, 2, tz, true); box(3, 2.5, 5, std(0x283038, { metal: 0.6, rough: 0.2 }), tx0 + 1.5, 4.6, tz);
    for (let k = 1; k <= 3; k++) { const x = tx0 - 3 - k * 11; box(10, 0.8, 9, std(0x787e86, { metal: 0.6 }), x, 1.8, tz); box(9, 7.4, 9, uldM[k % 4], x, 6, tz, true); for (const dx of [-3.5, 3.5]) for (const dz of [-4, 4]) wheelZ(x + dx, tz + dz, 1.1); }
    // погрузчик-платформа (K-loader) у дока
    const kx = CX - 120, kz = CZ - 75; box(14, 2, 10, yelM, kx, 1.8, kz, true); box(14, 1, 10, yelM, kx, 10, kz, true); box(9, 7.4, 9, uldM[1], kx, 14.7, kz, true);
    for (const s of [-1, 1]) { const a = new THREE.Mesh(new THREE.BoxGeometry(15, 0.8, 0.8), std(0x50565e, { metal: 0.7 })); a.position.set(kx, 6, kz + s * 4.6); a.rotation.z = s * 0.55; grp.add(a); }
    for (const dx of [-5, 5]) for (const dz of [-5.4, 5.4]) wheelZ(kx + dx, kz + dz, 1.3);
    { const a = apToWorld(ap, CX - 100, CZ - 130), b = apToWorld(ap, CX + 100, CZ + 130); obstacles.push({ min: { x: Math.min(a.x, b.x), y: 0, z: Math.min(a.z, b.z) }, max: { x: Math.max(a.x, b.x), y: 32, z: Math.max(a.z, b.z) } }); }
  }
"""

def add_cargo(s, patch):
    s = patch(s, "  // вышка\n", CARGO_JS + "  // вышка\n")
    s = patch(s, "  addLocalRect(ap, W / 2 + 880, W / 2 + 1320, -700, 700, 0.49);\n", "  addLocalRect(ap, W / 2 + 880, W / 2 + 1320, -700, 700, 0.49);\n  addLocalRect(ap, W / 2 + 700, W / 2 + 1130, 1000, 1520, 0.49);\n")
    return s
