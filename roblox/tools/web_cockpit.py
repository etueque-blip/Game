# 3D-кабина (веб) для вида «кабина» (V): козырёк, приборная панель с четырьмя «живыми» экранами
# (авиагоризонт и радар — те же холсты, что в интерфейсе, двигатели и сводка), рама окон, пульт с рычагами тяги.
# В Roblox то же — CockpitView в src/client/init.client.luau.
COCKPIT_JS = r"""
// ===== 3D-кабина
let cockpit = null; const ckTex = [];
function ckCanvas(draw) { const c = document.createElement("canvas"); c.width = c.height = 256; const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; ckTex.push({ c, t, draw }); return t; }
function ckEng(g, f) {
  g.fillStyle = "#05080f"; g.fillRect(0, 0, 256, 256); g.textAlign = "center"; g.textBaseline = "middle";
  const n1 = f.reverse ? 70 : 22 + f.throttle * 76;
  for (const [cx, lab] of [[70, "ДВ 1"], [186, "ДВ 2"]]) {
    g.lineWidth = 10; g.strokeStyle = "#1d2633"; g.beginPath(); g.arc(cx, 92, 48, Math.PI * 0.75, Math.PI * 2.25); g.stroke();
    g.strokeStyle = f.reverse ? "#f5a524" : "#3ddc84"; g.beginPath(); g.arc(cx, 92, 48, Math.PI * 0.75, Math.PI * (0.75 + 1.5 * n1 / 100)); g.stroke();
    g.fillStyle = "#fff"; g.font = "700 26px ui-monospace, Menlo, monospace"; g.fillText(n1.toFixed(0), cx, 94); g.fillStyle = "#8fa0b8"; g.font = "600 15px ui-sans-serif, system-ui"; g.fillText(lab + " N1 %", cx, 156);
  }
  g.font = "700 20px ui-monospace, Menlo, monospace"; g.fillStyle = f.gear ? "#3ddc84" : "#8fa0b8"; g.fillText(f.gear ? "ШАССИ ▼ ▼ ▼" : "ШАССИ УБРАНО", 128, 196);
  g.fillStyle = "#3dd6f5"; g.fillText("ЗАКРЫЛКИ " + (f.cfg.noFlaps ? "—" : f.flaps), 128, 228);
}
function ckInfo(g, f) {
  g.fillStyle = "#05080f"; g.fillRect(0, 0, 256, 256); g.textAlign = "left"; g.textBaseline = "middle";
  const look = new V3(0, 0, -1).applyQuaternion(f.att), hdg = (THREE.MathUtils.radToDeg(Math.atan2(look.x, -look.z)) + 360) % 360;
  const rows = [["СКОР", Math.round(f.speed * (METRIC ? 1.852 : 1)), METRIC ? "км/ч" : "kt", "#fff"], ["ВЫС", fmt(f.pos.y * FT * (METRIC ? 0.3048 : 1)), METRIC ? "м" : "ft", "#fff"],
    ["ВЕРТ", Math.round(vsSmooth / 10) * 10, "fpm", vsSmooth < -1500 ? "#e5484d" : "#3ddc84"], ["КУРС", String(Math.round(hdg) % 360).padStart(3, "0"), "°", "#e05bd8"]];
  rows.forEach(([k, v, u, col], i) => { const y = 36 + i * 60; g.fillStyle = "#8fa0b8"; g.font = "600 16px ui-sans-serif, system-ui"; g.fillText(k, 14, y); g.fillStyle = col; g.font = "700 34px ui-monospace, Menlo, monospace"; g.fillText(String(v), 82, y); g.fillStyle = "#8fa0b8"; g.font = "600 14px ui-sans-serif, system-ui"; g.fillText(u, 208, y + 4); });
}
function buildCockpit() {
  const g = new THREE.Group(), M = (c, r) => new THREE.MeshStandardMaterial({ color: lin(c), roughness: r, metalness: 0.2 });
  const panelM = M(0x262b33, 0.85), frameM = M(0x343a44, 0.7), trimM = M(0x4a515c, 0.5);
  const box = (sx, sy, sz, m, x, y, z, rx, rz) => { const o = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), m); o.position.set(x, y, z); o.rotation.set(rx || 0, 0, rz || 0); g.add(o); return o; };
  // приборная панель с наклоном, козырёк сверху
  box(3.2, 0.5, 0.06, panelM, 0, -0.655, -1.25, -0.28); box(3.2, 0.05, 0.22, frameM, 0, -0.37, -1.1, 0.08); box(3.2, 0.03, 0.03, trimM, 0, -0.33, -1.0);
  const scr = [new THREE.CanvasTexture($("adi")), new THREE.CanvasTexture($("radar")), ckCanvas(ckEng), ckCanvas(ckInfo)];
  scr[0].encoding = scr[1].encoding = THREE.sRGBEncoding; ckTex.push({ t: scr[0] }, { t: scr[1] });
  const pg = new THREE.Group(); pg.position.set(0, -0.655, -1.25); pg.rotation.x = -0.28; g.add(pg);
  [-0.92, -0.5, 0.5, 0.92].forEach((x, i) => { const bez = new THREE.Mesh(new THREE.BoxGeometry(0.38, 0.38, 0.02), trimM); bez.position.set(x, -0.02, 0.04); pg.add(bez);
    const s = new THREE.Mesh(new THREE.PlaneGeometry(0.33, 0.33), new THREE.MeshBasicMaterial({ map: scr[i], toneMapped: false })); s.position.set(x, -0.02, 0.052); pg.add(s); });
  // центральный пульт с рычагами тяги
  box(0.5, 0.22, 0.5, panelM, 0, -0.86, -0.95); const levers = [];
  for (const x of [-0.08, 0.08]) { const l = new THREE.Group(); l.position.set(x, -0.75, -0.95); g.add(l); const h = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.18, 0.04), trimM); h.position.y = 0.09; l.add(h); const k = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.04, 0.06), M(0x1b1f25, 0.6)); k.position.y = 0.19; l.add(k); levers.push(l); }
  // рама окон: боковые стойки и верх
  box(0.1, 1.8, 0.1, frameM, -1.38, 0.2, -1.15, 0, 0.22); box(0.1, 1.8, 0.1, frameM, 1.38, 0.2, -1.15, 0, -0.22); box(3.4, 0.14, 0.1, frameM, 0, 0.74, -1.12);
  g.userData.levers = levers; g.visible = false; scene.add(g); return g;
}
function cockpitFrame(f) {
  if (!cockpit) cockpit = buildCockpit();
  cockpit.visible = true; cockpit.position.copy(camera.position); cockpit.quaternion.copy(camera.quaternion);
  for (const l of cockpit.userData.levers) l.rotation.x = -0.6 + f.throttle * 1.1;
  for (const e of ckTex) { if (e.draw) e.draw(e.c.getContext("2d"), f); e.t.needsUpdate = true; }
}
"""

def add_cockpit(s, patch):
    s = patch(s, "function updateHUD(f) {", COCKPIT_JS + "function updateHUD(f) {")
    s = patch(s, "      camera.quaternion.copy(f.att); camera.up.set(0, 1, 0);\n", "      camera.quaternion.copy(f.att); camera.up.set(0, 1, 0);\n      if (!f.crashed && !PHOTO) cockpitFrame(f); else if (cockpit) cockpit.visible = false;\n")
    s = patch(s, "  drawRadar(f, hdg);\n", "  drawRadar(f, hdg); if (cockpit && camMode !== 1) cockpit.visible = false;\n")
    return s
