# 🎯 Посадочный вызов (веб): старт на заходе в 2,5 км от торца (≈ 450 ft, глиссада 3°), шасси и закрылки 2
# выпущены, скорость захода 1,3 × сваливания. Оценка посадки 0–100: вертикальная (до 50), ось (до 30),
# точка касания у знаков (до 20); рекорд по каждому аэропорту. Те же правила — Roblox (Challenge.luau).
CHAL_JS = r"""
// ===== посадочный вызов
const CHAL = {}; try { Object.assign(CHAL, JSON.parse(localStorage.getItem("skypilot.chal") || "{}")); } catch (e) {}
function approachSetup(f) {
  const c = f.cfg; f.flaps = c.noFlaps ? 0 : 2; f.gear = true; f.throttle = 0.45;
  f.speed = Math.round(c.stallKts * (1 - 0.07 * f.flaps) * 1.3); f.vel = new V3(0, 0, -1).applyQuaternion(f.att).multiplyScalar(f.speed); f.chalDone = false;
}
function chalScore(fpm, offM, zoneM) {
  const a = fpm < 100 ? 50 : fpm < 200 ? 42 : fpm < 350 ? 32 : fpm < 600 ? 18 : 5;
  const b = offM === null ? 0 : offM < 2 ? 30 : offM < 5 ? 24 : offM < 10 ? 16 : offM < 20 ? 8 : 0;
  const z = zoneM < 30 ? 20 : zoneM < 80 ? 14 : zoneM < 150 ? 8 : 0;
  return a + b + z;
}
function chalLanding(f, ap, fpm, offM) {
  if (!f.mode || !f.mode.startsWith("approach:") || f.chalDone) return; f.chalDone = true;
  const target = AIRPORTS.find((a) => "approach:" + a.id === f.mode);
  if (!ap || !target || ap.id !== target.id) { setTimeout(() => toast("🎯 Вызов не засчитан: посадка не на ту полосу", "var(--amber)"), 900); return; }
  const lz = ap.rot ? f.pos.x - ap.cx : f.pos.z - ap.cz, zoneM = Math.abs(lz - (ap.L / 2 - 300)) * 0.515;
  const sc = chalScore(fpm, offM, zoneM), best = CHAL[ap.id] || 0, rec = sc > best;
  if (rec) { CHAL[ap.id] = sc; try { localStorage.setItem("skypilot.chal", JSON.stringify(CHAL)); } catch (e) {} }
  setTimeout(() => toast(`🎯 Посадочный вызов ${ap.code}: ${sc}/100 · касание ${Math.round(zoneM)} м от знаков` + (rec ? " · новый рекорд!" : ` · рекорд ${best}`), rec ? "var(--green)" : ""), 900);
}
"""

CSS = """
/* меню: 4 малые плитки в ряд (добавлен «Посадочный вызов») */
.tiles { grid-template-columns: repeat(12, minmax(0, 1fr)); } .tile { grid-column: span 3; } .tile.big { grid-column: span 6; }
@media (max-width: 760px) { .tile, .tile.big { grid-column: span 12; } }
"""

def add_challenge(s, patch):
    s = patch(s, "</style>\n\n<div id=\"app\">", CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '<small>13 колец: Дубай → Ташкент → Лондон</small></button>', '<small>13 колец: Дубай → Ташкент → Лондон</small></button>\n        <button class="tile" data-m="landing" data-ph="mode_free"><span class="ic">🎯</span><b>Посадочный<br>вызов</b><small>Заход с 2,5 км: сядь идеально, рекорд по аэропорту</small></button>')
    s = patch(s, '  if (mode === "air") return { pos: new V3(0, 3000 / FT, 9000), yaw: 0, air: true };',
              '  if (mode === "air") return { pos: new V3(0, 3000 / FT, 9000), yaw: 0, air: true };\n'
              '  if (mode.startsWith("approach:")) { const ap = AIRPORTS.find((a) => "approach:" + a.id === mode) || AIRPORTS[0], w = apToWorld(ap, 0, ap.L / 2 + 4800); return { pos: new V3(w.x, 0.5 + cfg.gearHeight + 267, w.z), yaw: ap.rot ? Math.PI / 2 : 0, air: true }; }')
    s = patch(s, "  flight = newFlight(cfg, mode);\n", "  flight = newFlight(cfg, mode); if (mode.startsWith(\"approach:\")) approachSetup(flight);\n")
    s = patch(s, 'startFlight(withLivery(PLANES[FL.plane]), FL.mode === "race" ? "race" : "runway:" + FL.from);', 'startFlight(withLivery(PLANES[FL.plane]), FL.mode === "race" ? "race" : (FL.mode === "landing" ? "approach:" : "runway:") + FL.from);')
    s = patch(s, '$("fTitle").textContent = c ? c.name : FL.mode === "race" ? "Гонка колец" : FL.mode === "career" ? "Режим рейсов" : "Свободный полёт";',
              '$("fTitle").textContent = c ? c.name : FL.mode === "race" ? "Гонка колец" : FL.mode === "career" ? "Режим рейсов" : FL.mode === "landing" ? "Посадочный вызов" : "Свободный полёт";')
    s = patch(s, "function showLandingReport(f, ap, text, pts) {", CHAL_JS + "function showLandingReport(f, ap, text, pts) {")
    s = patch(s, '  if (ap) { const dx = f.pos.x - ap.cx, dz = f.pos.z - ap.cz; off = Math.abs(ap.rot ? -dz : dx) * 0.515; }\n',
              '  if (ap) { const dx = f.pos.x - ap.cx, dz = f.pos.z - ap.cz; off = Math.abs(ap.rot ? -dz : dx) * 0.515; }\n  chalLanding(f, ap, fpm, off);\n')
    s = patch(s, '  toast(mode === "air" ? "Вы в воздухе на 3000 ft — аэропорт впереди" :', '  toast(mode.startsWith("approach:") ? "🎯 Посадочный вызов: садись на полосу впереди — мягко, по оси и у посадочных знаков" : mode === "air" ? "Вы в воздухе на 3000 ft — аэропорт впереди" :')
    return s
