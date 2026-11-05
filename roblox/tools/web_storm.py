# Гроза и луна (веб). В ливень (RAIN.v > 0.6) раз в 6–20 с бьёт молния: ломаный разряд с ветками
# от облаков до земли в 1–5 км от камеры, вспышка неба и света, гром с задержкой по расстоянию.
# Ночью над горизонтом — луна напротив солнца. В Roblox то же самое — в src/client/init.client.luau (Storm).
STORM_JS = r"""
// ===== гроза и луна
const STORM = { next: 5, flash: 0, bolt: null, boltT: 0 }, FLASH_C = lin(0xdfe8ff);
const boltMat = new THREE.MeshBasicMaterial({ color: 0xf2f6ff, transparent: true, opacity: 0, depthWrite: false, fog: false });
function boltPath(a, b, n, jag) { const pts = [a.clone()]; for (let i = 1; i < n; i++) { const p = a.clone().lerp(b, i / n); p.x += R(-jag, jag); p.z += R(-jag, jag); p.y += R(-jag, jag) * 0.3; pts.push(p); } pts.push(b.clone()); return pts; }
function strike() {
  const ang = Math.random() * Math.PI * 2, dist = R(900, 5000), gx = camera.position.x + Math.cos(ang) * dist, gz = camera.position.z + Math.sin(ang) * dist;
  const gy = typeof terrainH === "function" ? terrainH(gx, gz) : 0, top = new V3(gx + R(-300, 300), Math.max(2400, gy + 2000), gz + R(-300, 300));
  if (STORM.bolt) { scene.remove(STORM.bolt); STORM.bolt.traverse((o) => o.geometry && o.geometry.dispose()); }
  const grp = new THREE.Group(), w = dist / 900 * 1.6;
  const seg = (pts, r) => { for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1], len = a.distanceTo(b);
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, len, 5, 1, true), boltMat); m.position.copy(a).lerp(b, 0.5); m.quaternion.setFromUnitVectors(new V3(0, 1, 0), b.clone().sub(a).normalize()); grp.add(m); } };
  const main = boltPath(top, new V3(gx, gy, gz), 16, 160); seg(main, w);
  for (let k = 0; k < 3; k++) { const i = 2 + Math.floor(Math.random() * 8), s = main[i], e = s.clone().add(new V3(R(-500, 500), -R(300, 700), R(-500, 500))); seg(boltPath(s, e, 6, 90), w * 0.55); }
  grp.renderOrder = 5; scene.add(grp); STORM.bolt = grp; STORM.boltT = 0.4; STORM.flash = 1;
  // гром: шумовой раскат с задержкой «скорость звука» (1 stud ≈ 0.515 м)
  if (AC && soundOn) try { const t0 = AC.currentTime + Math.min(8, dist * 0.515 / 343), len = 3.2;
    const buf = AC.createBuffer(1, AC.sampleRate * len, AC.sampleRate), d = buf.getChannelData(0); let last = 0;
    for (let i = 0; i < d.length; i++) { const t = i / AC.sampleRate; last = (last + 0.06 * (Math.random() * 2 - 1)) / 1.06; d[i] = last * 6 * Math.exp(-t * 1.3) * (0.6 + 0.4 * Math.sin(t * 7 + Math.random() * 0.3)); }
    const src = AC.createBufferSource(); src.buffer = buf; const lp = AC.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = dist < 2000 ? 900 : 380;
    const g = AC.createGain(); g.gain.value = clamp(1.6 - dist / 4000, 0.25, 1.2); src.connect(lp).connect(g).connect(AC.destination); src.start(t0); } catch (e) {}
}
let moon = null;
function moonStep(night) {
  if (!moon) { const c = document.createElement("canvas"); c.width = c.height = 128; const g = c.getContext("2d");
    const gr = g.createRadialGradient(64, 64, 20, 64, 64, 64); gr.addColorStop(0, "rgba(220,230,255,0.35)"); gr.addColorStop(0.5, "rgba(200,215,255,0.08)"); gr.addColorStop(1, "rgba(200,215,255,0)"); g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
    g.fillStyle = "#eef1f6"; g.beginPath(); g.arc(64, 64, 22, 0, Math.PI * 2); g.fill();
    g.fillStyle = "rgba(160,170,185,0.55)"; for (const [x, y, r] of [[56, 58, 5], [70, 70, 4], [68, 55, 3], [58, 72, 3.5], [74, 62, 2]]) { g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill(); }
    moon = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c), transparent: true, depthWrite: false, fog: false })); moon.renderOrder = -1; scene.add(moon); }
  const dir = SUN_DIR.clone().multiplyScalar(-1); dir.y = Math.abs(dir.y) * 0.8 + 0.12; dir.normalize();
  moon.visible = night > 0.05; moon.material.opacity = clamp(night * 1.3, 0, 1) * (1 - 0.85 * RAIN.v);
  moon.position.copy(camera.position).addScaledVector(dir, 40000); moon.scale.setScalar(8200);
}
function stormStep(dt) {
  if (RAIN.v > 0.6) { STORM.next -= dt; if (STORM.next <= 0) { STORM.next = 6 + Math.random() * 14; strike(); } } else STORM.next = Math.max(STORM.next, 3);
  if (STORM.flash > 0) { STORM.flash = Math.max(0, STORM.flash - dt * 2.6); const k = STORM.flash * (STORM.flash > 0.55 && Math.random() < 0.35 ? 0.3 : 1);
    hemi.intensity += 2.4 * k; renderer.toneMappingExposure += 0.55 * k; ZENITH.lerp(FLASH_C, 0.55 * k); HORIZON.lerp(FLASH_C, 0.45 * k); GROUND_HAZE.lerp(FLASH_C, 0.25 * k); }
  if (STORM.bolt) { STORM.boltT -= dt; boltMat.opacity = clamp(STORM.boltT / 0.25, 0, 1) * (Math.random() < 0.2 ? 0.4 : 1); STORM.bolt.visible = STORM.boltT > 0; }
}
"""

def add_storm(s, patch):
    s = patch(s, "function dayNight(dt) {", STORM_JS + "function dayNight(dt) {")
    s = patch(s, "  rainSky(dt);\n  scene.fog.color.copy(HORIZON);\n", "  rainSky(dt); stormStep(dt); moonStep(1 - day);\n  scene.fog.color.copy(HORIZON);\n")
    return s
