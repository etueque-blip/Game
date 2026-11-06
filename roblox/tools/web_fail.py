# 🔥 Аварийная тренировка (веб; включается в «⚙ Настройки»). На многомоторных самолётах в полёте выше 1500 ft,
# через 1–3 минуты в воздухе, отказывает один двигатель: тяга падает на его долю (физика: thrust × (1 − engOut),
# так же в FlightPhysics.luau), самолёт уводит в сторону отказавшего, за двигателем дым, предупреждение и «mayday».
# J — перезапуск (через 4 с, удачен в 70%). Посадка с отказавшим двигателем — достижение «Один мотор» (+600).
FAIL_JS = r"""
// ===== аварийная тренировка: отказ двигателя
var FAIL = false; try { FAIL = localStorage.getItem("skypilot.fail") === "1"; } catch (e) {}
const EF = { seq: -1, t: 0, at: 0, side: 0, restart: 0, done: false, smokeK: 0 };
const engCount = (c) => c.engines === "wing4" ? 4 : (c.engines === "wing2" || c.engines === "tail2" || c.engines === "turboprop2") ? 2 : 1;
function failTick(f, dt, input) {
  if (EF.seq !== window.__flightSeq) { EF.seq = window.__flightSeq; EF.t = 0; EF.at = 60 + Math.random() * 120; EF.side = 0; EF.restart = 0; EF.done = false; f.engOut = 0; }
  const n = engCount(f.cfg); if (!FAIL || n < 2 || f.crashed) return;
  if (!f.engOut && !EF.done) { if (!f.onGround && f.dbg.agl * FT > 1500) EF.t += dt;
    if (EF.t >= EF.at) { f.engOut = 1 / n; EF.side = Math.random() < 0.5 ? -1 : 1; toast("🔥 ОТКАЗ ДВИГАТЕЛЯ " + (EF.side < 0 ? 1 : n) + " · J — перезапуск", "var(--red)"); addLog("Отказ двигателя");
      const ap = AIRPORTS.slice().sort((a, b) => Math.hypot(a.cx - f.pos.x, a.cz - f.pos.z) - Math.hypot(b.cx - f.pos.x, b.cz - f.pos.z))[0]; atc(`Mayday принят. Ближайший аэропорт ${ap.code}, полоса свободна, заход по готовности.`); } }
  if (f.engOut > 0) {
    input.y = clamp(input.y + EF.side * 0.22 * f.throttle, -1, 1);
    if (EF.restart > 0) { EF.restart -= dt; if (EF.restart <= 0) { if (Math.random() < 0.7) { f.engOut = 0; EF.done = true; toast("✅ Двигатель перезапущен", "var(--green)"); } else toast("Перезапуск не удался — попробуй ещё (J)", "var(--amber)"); } }
    const u = planeObj && planeObj.userData; if (u && u.engines && u.engines.length && (EF.smokeK = (EF.smokeK + 1) % 3) === 0) { const e = u.engines[EF.side < 0 ? 0 : Math.floor(u.engines.length / 2)];
      spawnPuff(e.clone().applyQuaternion(f.att).add(f.pos), 0x45484e, f.cfg.diameter * 0.25, 3, f.cfg.diameter * 1.4, new V3(R(-1, 1), R(0, 2), R(-1, 1)), 0.6); }
  }
}
function failRestart() { if (flight && flight.engOut > 0 && EF.restart <= 0) { EF.restart = 4; toast("Перезапуск двигателя…", "var(--amber)"); } }
"""

def add_fail(s, patch):
    # физика: доля тяги отказавших двигателей (как FlightPhysics.luau)
    s = patch(s, "  let thrust = c.thrust * f.throttle * thrustMul;\n  if (f.reverse) thrust = -c.thrust * 0.45 * f.throttle;\n",
              "  let thrust = c.thrust * f.throttle * thrustMul * (1 - (f.engOut || 0));\n  if (f.reverse) thrust = -c.thrust * 0.45 * f.throttle * (1 - (f.engOut || 0));\n")
    s = patch(s, "function updateHUD(f) {", FAIL_JS + "function updateHUD(f) {")
    s = patch(s, "    const __prev = f.pos.clone();\n    physicsStep(f, input, dt);\n", "    const __prev = f.pos.clone();\n    failTick(f, dt, input);\n    physicsStep(f, input, dt);\n")
    s = patch(s, '  else if (f.flaps > 0 && f.speed > c.flapMaxKts) { w = "ЗАКРЫЛКИ: ПРЕВЫШЕНИЕ"; col = "var(--amber)"; }\n',
              '  else if (f.engOut > 0) { w = "ОТКАЗ ДВИГАТЕЛЯ · J — ПЕРЕЗАПУСК"; col = "var(--amber)"; }\n  else if (f.flaps > 0 && f.speed > c.flapMaxKts) { w = "ЗАКРЫЛКИ: ПРЕВЫШЕНИЕ"; col = "var(--amber)"; }\n')
    s = patch(s, 'KeyY: "smoke" };', 'KeyY: "smoke", KeyJ: "restart" };')
    s = patch(s, '  } else if (a === "smoke") {', '  } else if (a === "restart") { failRestart();\n  } else if (a === "smoke") {')
    s = patch(s, '    ["Сложность", ["Обычная", "Сложная (G)"],', '    ["Аварийная тренировка", ["Выкл", "Вкл"], () => (FAIL ? 1 : 0), (i) => { FAIL = i === 1; try { localStorage.setItem("skypilot.fail", FAIL ? "1" : "0"); } catch (e) {} }],\n    ["Сложность", ["Обычная", "Сложная (G)"],')
    # достижение «Один мотор»
    s = patch(s, '["ace", "⚡", "Ас", "Выдержи 8 G на F-16", 400], ["heavy", "🐘", "Тяжеловес", "Посади Airbus A380 или Boeing 747", 300],',
              '["ace", "⚡", "Ас", "Выдержи 8 G на F-16", 400], ["heavy", "🐘", "Тяжеловес", "Посади Airbus A380 или Boeing 747", 300], ["one_engine", "🔥", "Один мотор", "Посади самолёт с отказавшим двигателем", 600],')
    s = patch(s, "  chalLanding(f, ap, fpm, off);\n", "  chalLanding(f, ap, fpm, off);\n  if (ap && f.engOut > 0) achUnlock(\"one_engine\");\n")
    # экран двигателей в 3D-кабине: отказавший — 0 и красный
    s = patch(s, '  for (const [cx, lab] of [[70, "ДВ 1"], [186, "ДВ 2"]]) {\n', '  for (const [cx, lab] of [[70, "ДВ 1"], [186, "ДВ 2"]]) { const dead = f.engOut > 0 && ((EF.side < 0) === (cx < 128)), n1 = dead ? 0 : (f.reverse ? 70 : 22 + f.throttle * 76);\n')
    s = patch(s, "  const n1 = f.reverse ? 70 : 22 + f.throttle * 76;\n", "")
    s = patch(s, '    g.strokeStyle = f.reverse ? "#f5a524" : "#3ddc84"; g.beginPath();', '    g.strokeStyle = dead ? "#e5484d" : f.reverse ? "#f5a524" : "#3ddc84"; g.beginPath();')
    s = patch(s, '12 целей', '13 целей')
    return s
