# Авиашоу (веб): цветной дым из хвоста (Y / кнопка ДЫМ) и фигуры пилотажа с очками.
# Правила те же, что в src/shared/Aerobatics.luau: бочка 150, петля 250, перевёрнутый полёт 5 с — 120;
# паузы между одинаковыми фигурами 3/6/8 с, не больше 3000 очков за полёт, только выше 300 ft над землёй.
ACRO_JS = r"""
// ===== авиашоу: дым и фигуры пилотажа
const TRICKS = { roll: { title: "Бочка", pts: 150, gap: 3 }, loop: { title: "Петля", pts: 250, gap: 6 }, inverted: { title: "Перевёрнутый полёт", pts: 120, gap: 8 } };
const SMOKE = [null, [0xf5f5f5, "белый"], [0xeb3c3c, "красный"], [0x326eeb, "синий"], [0x3cbe5a, "зелёный"], [0xfac828, "жёлтый"]];
let smokeIdx = 0, smokeLast = null;
const acro = { prev: null, roll: 0, pitch: 0, rIdle: 0, pIdle: 0, inv: 0, invDone: false, rInv: false, pUp: false, pInv: false, at: {}, pts: 0, seq: -1, t: 0 };
function acroReset() { acro.roll = acro.pitch = acro.inv = 0; acro.rInv = acro.pUp = acro.pInv = false; }
function acroStep(f, dt, ok) {
  const prev = acro.prev; acro.prev = f.att.clone();
  if (!ok || !prev || dt <= 0) { acroReset(); return null; }
  const q = prev.clone().invert().multiply(f.att); if (q.w < 0) { q.x = -q.x; q.y = -q.y; q.z = -q.z; q.w = -q.w; }
  const ang = 2 * Math.acos(Math.min(1, q.w)), sn = Math.sqrt(Math.max(0, 1 - q.w * q.w));
  const dRoll = sn > 1e-6 ? q.z / sn * ang : 0, dPitch = sn > 1e-6 ? q.x / sn * ang : 0;
  const up = new V3(0, 1, 0).applyQuaternion(f.att), look = new V3(0, 0, -1).applyQuaternion(f.att);
  acro.rIdle = Math.abs(dRoll) / dt < 0.52 ? acro.rIdle + dt : 0; if (acro.rIdle > 1.5) { acro.roll = 0; acro.rInv = false; }
  acro.pIdle = Math.abs(dPitch) / dt < 0.14 ? acro.pIdle + dt : 0; if (acro.pIdle > 3) { acro.pitch = 0; acro.pUp = acro.pInv = false; }
  acro.roll += dRoll; acro.pitch += dPitch;
  if (up.y < -0.5) { acro.rInv = true; acro.pInv = true; }
  if (Math.abs(look.y) > 0.85) acro.pUp = true;
  if (Math.abs(acro.pitch) >= 5.76 && acro.pUp && acro.pInv) { acroReset(); return "loop"; }
  if (Math.abs(acro.roll) >= 5.93 && acro.rInv) { acro.roll = 0; acro.rInv = false; return "roll"; }
  if (up.y < -0.6) acro.inv += dt; else { acro.inv = 0; if (up.y > 0.3) acro.invDone = false; }
  if (acro.inv >= 5 && !acro.invDone) { acro.invDone = true; return "inverted"; }
  return null;
}
function acroTick(f) {
  const now = performance.now() / 1000, dt = Math.min(0.1, now - (acro.t || now)); acro.t = now;
  if (acro.seq !== window.__flightSeq) { acro.seq = window.__flightSeq; acro.at = {}; acro.pts = 0; acro.prev = null; acroReset(); smokeLast = null; }
  if (f.crashed) return;
  const id = acroStep(f, dt, !f.onGround && f.dbg.agl * FT > 300);
  if (id) { const t = TRICKS[id];
    if (now - (acro.at[id] || -1e9) >= t.gap && acro.pts + t.pts <= 3000) { acro.at[id] = now; acro.pts += t.pts; SCORE.points += t.pts; try { localStorage.setItem("skypilot.score", JSON.stringify(SCORE)); } catch (e) {}
      toast(`✈ ${t.title} · +${t.pts}`, "var(--green)"); addLog(`Фигура: ${t.title} +${t.pts}`); } }
  // дым из хвоста: шлейф пятнами с шагом по расстоянию (не больше ~20 в секунду)
  const sm = SMOKE[smokeIdx];
  if (!sm) { smokeLast = null; return; }
  const c = f.cfg, tail = new V3(0, 0, c.length * 0.5 + 1).applyQuaternion(f.att).add(f.pos);
  const step = Math.max(c.diameter * 0.6, f.speed * 0.035);
  if (!smokeLast) smokeLast = tail.clone();
  const d = tail.distanceTo(smokeLast);
  if (d > 3000) smokeLast.copy(tail);
  for (let k = Math.max(step, d - step * 60); k <= d; k += step) { const p = smokeLast.clone().lerp(tail, k / d);
    spawnPuff(p, sm[0], Math.max(6, c.diameter * 1.3, step * 1.4), 4.5, Math.max(18, c.diameter * 4), new V3(R(-1, 1), R(0, 1.5), R(-1, 1)), 0.85); }
  if (d >= step) smokeLast.copy(tail);
}
"""

def add_acro(s, patch):
    s = patch(s, "if (particles.length > 500) return;", "if (particles.length > 800) return;")
    s = patch(s, "function updateHUD(f) {", ACRO_JS + "function updateHUD(f) {")
    s = patch(s, "drawTape(hdg); drawPFD(f);\n", "drawTape(hdg); drawPFD(f); acroTick(f);\n")
    s = patch(s, 'KeyH: "photo" };', 'KeyH: "photo", KeyY: "smoke" };')
    s = patch(s, '  } else if (a === "spoiler") {', '  } else if (a === "smoke") { smokeIdx = (smokeIdx + 1) % SMOKE.length; toast(SMOKE[smokeIdx] ? "Дым: " + SMOKE[smokeIdx][1] + " · Y — сменить цвет" : "Дым выключен", SMOKE[smokeIdx] ? "var(--green)" : "");\n  } else if (a === "spoiler") {')
    s = patch(s, '      <button class="rb" id="tSpl">ИНТЕРЦ.</button>', '      <button class="rb" id="tSpl">ИНТЕРЦ.</button>\n      <button class="rb" id="tSmoke">ДЫМ</button>')
    s = patch(s, '$("tSpl").onclick = () => action("spoiler");', '$("tSpl").onclick = () => action("spoiler"); $("tSmoke").onclick = () => action("smoke");')
    s = patch(s, '<kbd>H</kbd> фото-режим</div>', '<kbd>H</kbd> фото-режим, <kbd>Y</kbd> дым (цвет)</div>')
    return s
