# Новая диспетчерская вышка и обзорный радар (веб). Вышка: сужающийся двухъярусный ствол, балкон, восьмигранная
# кабина с наклонным остеклением (ночью светится тёплым), крыша с антеннами и красным огнём.
# Радар: решётчатая мачта по другую сторону полосы, антенна вращается (~10 об/мин). Те же размеры — WorldBuilder.luau.
OLD = """  const tw = std(0xdfe2e6, { rough: 0.6 });
  mesh(grp, new THREE.CylinderGeometry(10, 13, 130, 24), tw, tx + 20, 65, 560, true);
  mesh(grp, new THREE.CylinderGeometry(22, 16, 16, 24), glass, tx + 20, 138, 560, true);
  mesh(grp, new THREE.CylinderGeometry(24, 24, 3, 24), std(0x3d434c, { metal: 0.6 }), tx + 20, 147.5, 560, true);
  red.push({ x: tx + 20, y: 152, z: 560, sx: 3, sy: 3, sz: 3 });
"""
NEW = r"""  { const tw = std(0xdfe2e6, { rough: 0.6 }), dark = std(0x3d434c, { metal: 0.6 }), X = tx + 20, Z = 560;
    mesh(grp, new THREE.CylinderGeometry(9, 14, 100, 24), tw, X, 50, Z, true);
    mesh(grp, new THREE.CylinderGeometry(7.5, 9, 30, 24), std(0xc9ced5, { rough: 0.5 }), X, 115, Z, true);
    mesh(grp, new THREE.CylinderGeometry(17, 17, 1.5, 24), dark, X, 130.5, Z, true);
    mesh(grp, new THREE.CylinderGeometry(17.2, 17.2, 1.4, 24, 1, true), std(0xaeb4bc, { metal: 0.7 }), X, 132.5, Z);
    const cabM = new THREE.MeshStandardMaterial({ color: lin(0x22384f), metalness: 0.85, roughness: 0.08, envMap, emissive: lin(0xffd9a0), emissiveIntensity: 0 });
    (window.__towerCabs || (window.__towerCabs = [])).push(cabM);
    mesh(grp, new THREE.CylinderGeometry(21, 15, 15, 8), cabM, X, 139, Z, true);
    for (let i = 0; i < 8; i++) { const a = (i + 0.5) / 8 * Math.PI * 2, m = mesh(grp, new THREE.BoxGeometry(0.8, 15.5, 0.8), dark, X + Math.cos(a) * 18, 139, Z + Math.sin(a) * 18); m.rotation.set(Math.sin(a) * 0.38, 0, -Math.cos(a) * 0.38); }
    mesh(grp, new THREE.CylinderGeometry(23, 23, 2.5, 8), dark, X, 148, Z, true); mesh(grp, new THREE.CylinderGeometry(10, 14, 4, 8), tw, X, 151.2, Z, true);
    for (const [dx, h] of [[-4, 14], [5, 10]]) mesh(grp, new THREE.BoxGeometry(0.6, h, 0.6), std(0xd0d4da, { metal: 0.8 }), X + dx, 153 + h / 2, Z);
    red.push({ x: X - 4, y: 167.5, z: Z, sx: 2, sy: 2, sz: 2 });
  }
  // обзорный радар на решётчатой мачте (антенна вращается в radarStep)
  { const RX = -(W / 2 + 320), RZ = -900, steel = std(0xb9bfc7, { metal: 0.8, rough: 0.35 });
    box(44, 1, 44, std(0xa5a5a0, { rough: 0.9 }), RX, 0.5, RZ);
    for (const sx of [-6, 6]) for (const sz of [-6, 6]) box(1.2, 40, 1.2, steel, RX + sx, 20, RZ + sz, true);
    for (let k = 1; k <= 4; k++) for (const [w, d, dx, dz] of [[12, 0.6, 0, -6], [12, 0.6, 0, 6], [0.6, 12, -6, 0], [0.6, 12, 6, 0]]) box(w, 0.6, d, steel, RX + dx, k * 9, RZ + dz);
    box(16, 1.5, 16, std(0x5a6068, { metal: 0.6 }), RX, 41, RZ, true); mesh(grp, new THREE.CylinderGeometry(2, 2.6, 4, 12), steel, RX, 43.5, RZ);
    const rot = new THREE.Group(); rot.position.set(RX, 46, RZ); grp.add(rot);
    const dish = new THREE.Mesh(new THREE.BoxGeometry(34, 9, 1.2), std(0xe8ebef, { metal: 0.4, rough: 0.4 })); dish.position.set(0, 3, -1.5); dish.rotation.x = -0.25; rot.add(dish);
    const arm = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 7), steel); arm.position.set(0, 0.5, 2.5); rot.add(arm);
    (window.__radars || (window.__radars = [])).push(rot);
    const a = apToWorld(ap, RX - 8, RZ - 8), b = apToWorld(ap, RX + 8, RZ + 8); obstacles.push({ min: { x: Math.min(a.x, b.x), y: 0, z: Math.min(a.z, b.z) }, max: { x: Math.max(a.x, b.x), y: 52, z: Math.max(a.z, b.z) } });
  }
"""
STEP = r"""
function radarStep(dt, day) {
  if (window.__radars) for (const r of window.__radars) r.rotation.y += dt * 1.05;
  if (window.__towerCabs) for (const m of window.__towerCabs) m.emissiveIntensity = 0.55 * (1 - day);
}
"""

def add_tower(s, patch):
    s = patch(s, OLD, NEW)
    s = patch(s, "function dayNight(dt) {", STEP + "function dayNight(dt) {")
    s = patch(s, "rainbowStep(dt, day); stormStep(dt);", "rainbowStep(dt, day); radarStep(dt, day); stormStep(dt);")
    s = patch(s, "  addLocalRect(ap, W / 2 + 700, W / 2 + 1130, 1000, 1520, 0.49);\n", "  addLocalRect(ap, W / 2 + 700, W / 2 + 1130, 1000, 1520, 0.49);\n  addLocalRect(ap, -(W / 2 + 350), -(W / 2 + 290), -930, -870, 0.49);\n")
    return s
