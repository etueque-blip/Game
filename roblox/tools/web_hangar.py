# Ангары техобслуживания (веб): открытые ворота, полая арочная крыша из панелей, задняя стена-полукруг,
# раздвинутые створки ворот, светлый пол с разметкой, лампы под крышей, внутри самолёт на обслуживании со стремянками.
# Те же размеры — в src/server/WorldBuilder.luau (ангар 170 × 210, арка радиусом 105 на стенах 30).
OLD = """  // ангары с арочной крышей
  for (const z of [-1130, -1370]) {
    const hw = std(0xb7bec8, { metal: 0.7, rough: 0.35 });
    box(170, 30, 210, hw, W / 2 + 790, 15, z, true);
    const roof = mesh(grp, new THREE.CylinderGeometry(105, 105, 170, 32, 1, false, 0, Math.PI), hw, W / 2 + 790, 30, z, true);
    roof.rotation.z = Math.PI / 2;
    box(1, 28, 180, std(0x4a525e, { metal: 0.6, rough: 0.5 }), W / 2 + 704.5, 15, z);
  }
"""

NEW = r"""  // ангары техобслуживания: открытые ворота, полая арочная крыша, внутри самолёт на обслуживании
  { const hw = std(0xb7bec8, { metal: 0.7, rough: 0.35, side: THREE.DoubleSide }), floorM = std(0xcdd1d6, { metal: 0.1, rough: 0.3 }), yelM = std(0xf2be28, { rough: 0.5 });
    const lampM = basic(0xfff4dc), doorM = std(0xd3d8de, { metal: 0.5, rough: 0.4 }), bandM = std(0x1f4f9a, { rough: 0.5 }), R0 = 105, N = 12, pw = 2 * R0 * Math.sin(Math.PI / N / 2) + 0.6, HX = W / 2 + 790;
    for (const [z, pid] of [[-1130, "B737"], [-1370, "A220"]]) {
      for (const s of [-1, 1]) box(170, 30, 2, hw, HX, 15, z + s * R0, true);
      for (let i = 0; i < N; i++) { const th = -Math.PI / 2 + (i + 0.5) * Math.PI / N; box(170, 2, pw, hw, HX, 30 + R0 * Math.cos(th), z + R0 * Math.sin(th), true).rotation.x = th; }
      box(2, 30, 210, hw, HX + 85, 15, z, true);
      mesh(grp, new THREE.CircleGeometry(R0, 24, 0, Math.PI), hw, HX + 85, 30, z, true).rotation.y = -Math.PI / 2;
      // фронтон над воротами и боковые стойки (по форме арки)
      { const sh = new THREE.Shape(); sh.moveTo(-R0, -30); sh.lineTo(-85, -30); sh.lineTo(-85, 62); sh.lineTo(85, 62); sh.lineTo(85, -30); sh.lineTo(R0, -30); sh.lineTo(R0, 0); sh.absarc(0, 0, R0, 0, Math.PI, false); sh.lineTo(-R0, -30);
        const fr = mesh(grp, new THREE.ShapeGeometry(sh, 24), hw, HX - 85, 30, z, true); fr.rotation.y = -Math.PI / 2;
        box(1.5, 4, 172, std(0x4a525e, { metal: 0.6, rough: 0.5 }), HX - 86, 92, z); }
      // створки ворот, сдвинутые к краям
      for (const s of [-1, 1]) for (let k = 0; k < 3; k++) { const dx = HX - 87 - k * 1.6, dz = z + s * (96 - k * 3); box(1, 84, 24, doorM, dx, 42.5, dz, true); box(1.1, 4, 24, bandM, dx, 12, dz); }
      // пол, разметка, лампы
      box(166, 0.2, 206, floorM, HX, 0.58, z); for (const s of [-1, 1]) box(150, 0.05, 1.2, yelM, HX, 0.7, z + s * 80);
      for (const zo of [-50, 0, 50]) box(150, 0.6, 2.4, lampM, HX, 30 + Math.sqrt(R0 * R0 - zo * zo) - 3, z + zo);
      // самолёт на обслуживании (носом к воротам) и стремянки у двигателей и носа
      const c = PLANES[pid], pm = buildPlane(c, true); pm.position.set(HX - 10, 0.5 + c.gearHeight, z); pm.rotation.y = Math.PI / 2; grp.add(pm);
      for (const s of [-1, 1]) { const sz = z + s * c.span * 0.17; box(10, 1, 9, yelM, HX - 10 - c.length * 0.03, 7, sz, true); for (const a of [-4, 4]) for (const b of [-3.5, 3.5]) box(0.6, 7, 0.6, yelM, HX - 10 - c.length * 0.03 + a, 3.5, sz + b); }
      box(7, 1, 7, yelM, HX - 10 - c.length * 0.5 + 6, c.gearHeight + 0.5, z + c.diameter * 0.7, true);
      for (let k = 0; k < 4; k++) box(7, 0.5, 2, yelM, HX - 10 - c.length * 0.5 + 6, 0.5 + (k + 0.5) * (c.gearHeight / 4), z + c.diameter * 0.7 + 4 + k * 2);
    }
  }
"""

def add_hangar(s, patch):
    return patch(s, OLD, NEW)
