# Утренний туман и блики от солнца (веб). Туман: в 60% дней с рассвета (≈4:30) до ≈9:00, сильнее всего в 6:50;
# у земли видимость падает, выше ~1500 ft — ясно; на панели погоды «туман». В Roblox то же (атрибут Mist, updateSky).
# Блики: свечение у солнца и «призраки» объектива вдоль линии солнце — центр экрана, когда смотришь в сторону солнца.
MIST_JS = r"""
// ===== утренний туман
const MIST = { day: Math.random() < 0.6, v: 0, last: 0 }, MIST_C = lin(0xdfe3e8);
function mistTarget(clock) { return MIST.day ? clamp(1 - Math.abs(clock - 6.8) / 2.3, 0, 1) : 0; }
function mistStep(dt, day) {
  if (MIST.last < 3.5 && gameClock >= 3.5) MIST.day = Math.random() < 0.6; MIST.last = gameClock;
  MIST.v += clamp(mistTarget(gameClock) - MIST.v, -0.02 * dt, 0.02 * dt);
  const m = MIST.v, r = RAIN.v; if (m < 0.01) { if (MIST.was) { MIST.was = false; scene.fog.near = 2500 * (1 - 0.7 * r); scene.fog.far = 36000 * (1 - 0.62 * r); } return; } MIST.was = true;
  const agl = Math.max(0, camera.position.y - (typeof groundAt === "function" ? groundAt(camera.position.x, camera.position.z) : 0)), low = clamp(1.15 - agl / 900, 0.15, 1), k = m * low;
  const c = MIST_C.clone().multiplyScalar(0.25 + 0.75 * day);
  HORIZON.lerp(c, 0.65 * k); GROUND_HAZE.lerp(c, 0.8 * k); ZENITH.lerp(c, 0.25 * k);
  scene.fog.near = 2500 * (1 - 0.7 * r) * (1 - 0.95 * k); scene.fog.far = 36000 * (1 - 0.62 * r) * (1 - 0.9 * k); sun.intensity *= 1 - 0.45 * k;
}
// ===== блики от солнца
let flareEls = null; const FLARE = [[0, 300, "rgba(255,246,220,0.55)"], [0.35, 46, "rgba(150,200,255,0.38)"], [0.6, 90, "rgba(255,200,140,0.26)"], [0.9, 30, "rgba(180,255,210,0.36)"], [1.25, 130, "rgba(140,170,255,0.2)"], [1.6, 60, "rgba(255,170,120,0.28)"]];
function flareStep(day) {
  if (!flareEls) { const box = document.createElement("div"); box.id = "flare"; box.style.cssText = "position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:1;mix-blend-mode:screen";
    flareEls = FLARE.map(([, s, col]) => { const d = document.createElement("div"); d.style.cssText = `position:absolute;width:${s}px;height:${s}px;margin:-${s / 2}px 0 0 -${s / 2}px;border-radius:50%;background:radial-gradient(circle, ${col} 0%, rgba(0,0,0,0) 70%)`; box.appendChild(d); return d; });
    const cv = $("c"); cv.parentNode.insertBefore(box, cv.nextSibling); }
  const p = camera.position.clone().addScaledVector(SUN_DIR, 30000).project(camera), W = innerWidth, H = innerHeight;
  const fwd = new V3(0, 0, -1).applyQuaternion(camera.quaternion), facing = fwd.dot(SUN_DIR);
  let a = flight && !flight.crashed ? clamp((facing - 0.55) / 0.35, 0, 1) * clamp(SUN_DIR.y * 8 + 0.3, 0, 1) * day * (1 - RAIN.v) * (1 - 0.8 * MIST.v) : 0;
  if (p.z > 1 || Math.abs(p.x) > 1.3 || Math.abs(p.y) > 1.3) a = 0;
  const sx = (p.x + 1) / 2 * W, sy = (1 - p.y) / 2 * H, cx = W / 2, cy = H / 2;
  FLARE.forEach(([t], i) => { const e = flareEls[i]; e.style.opacity = a.toFixed(3); e.style.left = (sx + (cx - sx) * t * 2) + "px"; e.style.top = (sy + (cy - sy) * t * 2) + "px"; });
}
"""

def add_mist(s, patch):
    s = patch(s, "function dayNight(dt) {", MIST_JS + "function dayNight(dt) {")
    s = patch(s, "  rainSky(dt); stormStep(dt); moonStep(1 - day);\n", "  rainSky(dt); mistStep(dt, day); stormStep(dt); moonStep(1 - day); flareStep(day);\n")
    s = patch(s, '${RAIN.v > 0.6 ? " · ливень" : RAIN.v > 0.15 ? " · дождь" : ""}</small>`; }', '${RAIN.v > 0.6 ? " · ливень" : RAIN.v > 0.15 ? " · дождь" : ""}${MIST.v > 0.3 ? " · туман" : ""}</small>`; }')
    s = patch(s, '`${RAIN.v > 0.15 ? "🌧" : ic} ${ph}', '`${RAIN.v > 0.15 ? "🌧" : MIST.v > 0.3 ? "🌫" : ic} ${ph}')
    return s
