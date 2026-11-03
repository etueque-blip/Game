#!/usr/bin/env python3
"""Собирает веб-версию Sky Pilot (web/SkyPilot.html) из HTML-полигона + данных городов.

Города (Дубай, Лондон, Ташкент) берутся из tools/cities.json — те же, что в Roblox.
Запуск: python3 tools/gen_cities.py && python3 tools/build_web.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "SkyPilot-test-polygon.html")
OUT = os.path.join(ROOT, "web", "SkyPilot.html")


def patch(s, old, new):
    if old not in s:
        raise SystemExit("не найден фрагмент: " + old[:70])
    return s.replace(old, new, 1)


def cut(s, start, end, new):
    a = s.index(start)
    b = s.index(end, a)
    return s[:a] + new + s[b:]


CITY_RENDER = r"""// города: Дубай, Лондон, Ташкент (данные общие с Roblox-версией, tools/gen_cities.py)
{
  const wedgeGeo = new THREE.BoxGeometry(1, 1, 1);
  { const p = wedgeGeo.attributes.position; for (let i = 0; i < p.count; i++) if (p.getY(i) > 0 && p.getZ(i) < 0) p.setY(i, -0.5); wedgeGeo.computeVertexNormals(); }
  const geoms = {
    box: new THREE.BoxGeometry(1, 1, 1),
    cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 24).rotateZ(Math.PI / 2),
    ball: new THREE.SphereGeometry(0.5, 20, 14),
    ell: new THREE.SphereGeometry(0.5, 28, 18),
    wedge: wedgeGeo,
  };
  const mats = {
    glass: new THREE.MeshStandardMaterial({ metalness: 0.75, roughness: 0.12, envMap, envMapIntensity: 1.5 }),
    metal: new THREE.MeshStandardMaterial({ metalness: 0.6, roughness: 0.35, envMap }),
    matte: new THREE.MeshStandardMaterial({ metalness: 0.02, roughness: 0.88, envMap, envMapIntensity: 0.6 }),
    water: new THREE.MeshStandardMaterial({ metalness: 0.4, roughness: 0.05, envMap, envMapIntensity: 1.3 }),
    neon: new THREE.MeshBasicMaterial({ color: 0xffffff }),
  };
  const cls = (p) => p[11] === "Neon" ? "neon" : p[11] === "Metal" ? "metal" : p[11] === "Glass" ? (p[5] < 1 ? "water" : "glass") : "matte";
  const groups = {};
  for (const p of CITYDATA.props) { const k = p[0] + "|" + cls(p); (groups[k] || (groups[k] = [])).push(p); }
  const m4 = new THREE.Matrix4(), q = new Q(), e = new THREE.Euler(), pos = new V3(), scl = new V3(), col = new THREE.Color();
  for (const k in groups) {
    const [kind, c] = k.split("|"), items = groups[k];
    const im = new THREE.InstancedMesh(geoms[kind], mats[c], items.length);
    items.forEach((p, i) => {
      pos.set(p[1], p[2], p[3]); scl.set(p[4], p[5], p[6]); e.set(p[7], p[8], p[9], "XYZ"); q.setFromEuler(e);
      m4.compose(pos, q, scl); im.setMatrixAt(i, m4);
      col.setHex(p[10]).convertSRGBToLinear(); im.setColorAt(i, col);
    });
    if (c !== "water" && c !== "neon") { im.castShadow = true; im.receiveShadow = true; } else im.receiveShadow = true;
    scene.add(im);
  }
  for (const l of CITYDATA.labels) {
    const t = canvasTex(512, 96, (x) => { x.font = "900 72px Russo One, Arial Black, Arial"; x.textAlign = "center"; x.textBaseline = "middle"; x.lineWidth = 10; x.strokeStyle = "rgba(10,20,40,.7)"; x.strokeText(l.name, 256, 50); x.fillStyle = "#fff"; x.fillText(l.name, 256, 50); });
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, transparent: true, depthWrite: false, fog: false }));
    s.scale.set(1400, 262, 1); s.position.set(l.x, l.y, l.z); scene.add(s);
  }
}

"""


NAV_JS = r"""
const NAV = [["SKP · SKYPORT INTERNATIONAL", 0, 0], ["MTV · MOUNTAIN VIEW AIRPORT", 14000, -16000], ["LNW · LONDON WEST", -9000, 15500], ["DXC · DUBAI COAST", 11500, -9000], ["TSE · TASHKENT EAST", 14500, 6500], ["ДУБАЙ", 5500, -7500], ["ЛОНДОН", -4000, 12500], ["ТАШКЕНТ", 10500, 3000]];
let navIdx = 0;
function cycleNav() { navIdx = (navIdx + 1) % (NAV.length + 1); const n = NAV[navIdx - 1]; toast(n ? "Навигация: " + n[0] : "Навигация выключена", "var(--magenta)"); if (!n) $("nav").hidden = true; }
function updateNav(f, hdg) {
  const n = NAV[navIdx - 1], el = $("nav");
  if (!n || !f || f.crashed) { el.hidden = true; return; }
  const dx = n[1] - f.pos.x, dz = n[2] - f.pos.z;
  const brg = (THREE.MathUtils.radToDeg(Math.atan2(dx, -dz)) + 360) % 360;
  const rel = ((brg - hdg + 540) % 360) - 180;
  const km = Math.hypot(dx, dz) * 0.515 / 1000;
  el.hidden = false;
  el.innerHTML = `<span class="arrow" style="transform:rotate(${rel.toFixed(0)}deg)">↑</span>${n[0]} · ${km.toFixed(1)} км · курс ${String(Math.round(brg) % 360).padStart(3, "0")}°`;
}
"""


def add_nav(s):
    """Навигация (клавиша N): стрелка на аэропорт или город, расстояние и курс."""
    s = patch(s, "#warn {", "#nav { position: absolute; top: calc(122px + env(safe-area-inset-top, 0px)); left: 50%; transform: translateX(-50%); background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 5px 12px 5px 8px; font-family: var(--f-num); font-size: 13px; white-space: nowrap; max-width: calc(100% - 140px); overflow: hidden; text-overflow: ellipsis; backdrop-filter: blur(6px); }\n#nav .arrow { display: inline-block; color: var(--magenta); margin-right: 8px; font-weight: 700; font-size: 16px; }\n#warn {")
    s = patch(s, "#toast { position: absolute; top: calc(126px", "#toast { position: absolute; top: calc(162px")
    s = patch(s, '<button class="tb" id="bCam">Камера: сзади</button>', '<button class="tb" id="bCam">Камера: сзади</button>\n    <button class="tb" id="bNav">Навигация</button>')
    s = patch(s, '<div id="warn"></div>', '<div id="nav" hidden></div>\n  <div id="warn"></div>')
    s = patch(s, '<div><kbd>V</kbd> камера, <kbd>M</kbd> ангар</div>', '<div><kbd>V</kbd> камера, <kbd>M</kbd> ангар</div>\n        <div><kbd>N</kbd> навигация: стрелка на аэропорт или город</div>')
    s = patch(s, 'KeyV: "cam", KeyM: "hangar" };', 'KeyV: "cam", KeyM: "hangar", KeyN: "nav" };')
    s = patch(s, 'if (a === "cam") { cycleCam(); return; }', 'if (a === "cam") { cycleCam(); return; }\n  if (a === "nav") { cycleNav(); return; }')
    s = patch(s, '$("bCam").onclick = () => cycleCam();', '$("bCam").onclick = () => cycleCam();\n$("bNav").onclick = () => cycleNav();')
    s = patch(s, '  drawADI(pitchDeg, bankDeg);\n', '  drawADI(pitchDeg, bankDeg);\n  updateNav(f, hdg);\n')
    s = patch(s, "// ============================================================ HUD\n", "// ============================================================ HUD\n" + NAV_JS)
    return s


RACE_JS = r"""
// ===== гонка через кольца и радар (те же кольца, что в Roblox)
const RINGS = CITYDATA.rings.map((d) => {
  const [x, y, z, r, yaw, name] = d;
  const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = yaw;
  const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.6 });
  g.add(new THREE.Mesh(new THREE.TorusGeometry(r, Math.max(2, r * 0.07), 8, 40), mat));
  scene.add(g); g.updateMatrixWorld(true);
  return { g, mat, r, name, inv: new THREE.Matrix4().copy(g.matrixWorld).invert(), pos: new V3(x, y, z) };
});
let raceIdx = 0, raceStart = null, bestRace = null;
try { const b = parseFloat(localStorage.getItem("skypilot.bestRace")); if (b > 0) bestRace = b; } catch (e) {}
function racePaint() { RINGS.forEach((rg, i) => { rg.mat.color.setHex(i < raceIdx ? 0x4dff95 : i === raceIdx ? 0xff4fd8 : 0xebf0ff); rg.mat.opacity = i < raceIdx ? 0.3 : i === raceIdx ? 1 : 0.55; }); }
function raceReset() { raceIdx = 0; raceStart = null; racePaint(); }
const fmtT = (t) => Math.floor(t / 60) + ":" + (t % 60).toFixed(1).padStart(4, "0");
function raceStep(prev, pos) {
  const rg = RINGS[raceIdx]; if (!rg) return;
  const a = prev.clone().applyMatrix4(rg.inv), b = pos.clone().applyMatrix4(rg.inv);
  if ((a.z > 0) === (b.z > 0) || Math.abs(a.z - b.z) < 1e-6) return;
  const p = a.lerp(b, a.z / (a.z - b.z));
  if (p.x * p.x + p.y * p.y > (rg.r * 1.1) ** 2) return;
  const now = performance.now() / 1000;
  if (raceIdx === 0) raceStart = now;
  raceIdx++;
  if (raceIdx >= RINGS.length) {
    const t = now - raceStart;
    let msg = "ФИНИШ гонки: " + fmtT(t);
    if (!bestRace || t < bestRace) { bestRace = t; msg += " · новый рекорд!"; try { localStorage.setItem("skypilot.bestRace", String(t)); } catch (e) {} }
    toast(msg, "var(--green)"); addLog(msg); raceIdx = 0; raceStart = null; setTimeout(racePaint, 3000);
  } else toast(`Кольцо ${raceIdx}/${RINGS.length} · ${rg.name}`, "var(--magenta)");
  racePaint();
}
racePaint();
function raceTarget() { return raceStart !== null ? RINGS[raceIdx] : null; }
const radarCv = document.getElementById("radar"), rctx = radarCv.getContext("2d");
function drawRadar(f, hdg) {
  const S = radarCv.width, R = S / 2, RANGE = 12000, k = (R - 6) / RANGE, h = THREE.MathUtils.degToRad(hdg);
  rctx.clearRect(0, 0, S, S);
  rctx.save(); rctx.beginPath(); rctx.arc(R, R, R - 1, 0, Math.PI * 2); rctx.fillStyle = "rgba(9,17,33,.72)"; rctx.fill(); rctx.clip();
  rctx.strokeStyle = "rgba(120,170,255,.22)"; rctx.lineWidth = 2;
  for (const q of [0.33, 0.66]) { rctx.beginPath(); rctx.arc(R, R, (R - 6) * q, 0, Math.PI * 2); rctx.stroke(); }
  const put = (x, z, edge) => {
    const east = x - f.pos.x, north = -(z - f.pos.z);
    let rx = east * Math.cos(h) - north * Math.sin(h), up = east * Math.sin(h) + north * Math.cos(h);
    const d = Math.hypot(rx, up), m = RANGE * 0.72;
    if (d > m) { if (!edge) return null; rx *= m / d; up *= m / d; }
    return [R + rx * k, R - up * k];
  };
  rctx.textAlign = "center"; rctx.textBaseline = "middle";
  const label = (txt, x, z, col, size) => { const p = put(x, z, true); if (!p) return; rctx.font = `600 ${size}px IBM Plex Sans, sans-serif`; rctx.fillStyle = col; rctx.fillText(txt, p[0], p[1]); };
  for (const ap of AIRPORTS) label(ap.id, ap.cx, ap.cz, "#e4eeff", 24);
  label("Дубай", 5500, -7500, "#8ea3c4", 20); label("Лондон", -4000, 12500, "#8ea3c4", 20); label("Ташкент", 10500, 3000, "#8ea3c4", 20);
  const rt = raceTarget() || RINGS[0]; label("◎", rt.pos.x, rt.pos.z, "#ff4fd8", 26);
  rctx.restore();
  rctx.fillStyle = "#ffbf3c"; rctx.beginPath(); rctx.moveTo(R, R - 10); rctx.lineTo(R + 7, R + 8); rctx.lineTo(R, R + 4); rctx.lineTo(R - 7, R + 8); rctx.closePath(); rctx.fill();
}
"""


def add_race_radar(s):
    """Гонка через 13 колец (Дубай → Ташкент → Лондон) и радар с курсом вверх."""
    s = patch(s, "#warn {", "#radar { position: absolute; left: calc(8px + env(safe-area-inset-left, 0px)); top: calc(122px + env(safe-area-inset-top, 0px)); width: 140px; height: 140px; }\n#race { position: absolute; right: calc(10px + env(safe-area-inset-right, 0px)); top: calc(224px + env(safe-area-inset-top, 0px)); background: var(--magenta); color: #1a0216; border-radius: 6px; padding: 3px 9px; font-family: var(--f-num); font-weight: 600; font-size: 13px; }\n#debug { top: calc(272px + env(safe-area-inset-top, 0px)) !important; }\n#warn {")
    s = patch(s, '<div id="nav" hidden></div>', '<div id="nav" hidden></div>\n  <canvas id="radar" width="280" height="280" hidden></canvas>\n  <div id="race" hidden></div>')
    s = patch(s, "// ============================================================ HUD\n", "// ============================================================ HUD\n" + RACE_JS)
    s = patch(s, "    physicsStep(f, input, dt);\n", "    const __prev = f.pos.clone();\n    physicsStep(f, input, dt);\n    if (!f.crashed) raceStep(__prev, f.pos);\n")
    s = patch(s, "  lastCfg = cfg; lastMode = mode;\n", "  lastCfg = cfg; lastMode = mode; raceReset();\n")
    s = patch(s, '  crashTimer = 1.8; $("crashReason").textContent = reason; $("hud").hidden = true; $("adi").hidden = true;', '  crashTimer = 1.8; $("crashReason").textContent = reason; $("hud").hidden = true; $("adi").hidden = true; $("radar").hidden = true; $("race").hidden = true; $("nav").hidden = true; raceReset();')
    s = patch(s, '$("hud").hidden = false; $("adi").hidden = false;', '$("hud").hidden = false; $("adi").hidden = false; $("radar").hidden = false;')
    s = patch(s, "  updateNav(f, hdg);\n", "  updateNav(f, hdg);\n  drawRadar(f, hdg);\n  { const el = $(\"race\"); if (raceStart !== null) { el.hidden = false; el.textContent = `КОЛЬЦА ${raceIdx}/${RINGS.length} · ${fmtT(performance.now() / 1000 - raceStart)}`; } else el.hidden = true; }\n")
    # навигация во время гонки показывает следующее кольцо
    s = patch(s, "  const n = NAV[navIdx - 1], el = $(\"nav\");\n  if (!n || !f || f.crashed) { el.hidden = true; return; }",
              "  const rt = raceTarget() || (lastMode === \"race\" ? Object.assign({}, RINGS[0], { name: \"Старт гонки\" }) : null);\n  const n = rt ? [\"КОЛЬЦО · \" + rt.name + \" · \" + Math.round(rt.pos.y * FT) + \" ft\", rt.pos.x, rt.pos.z] : NAV[navIdx - 1], el = $(\"nav\");\n  if (!n || !f || f.crashed) { el.hidden = true; return; }")
    s = patch(s, '<div><kbd>N</kbd> навигация: стрелка на аэропорт или город</div>', '<div><kbd>N</kbd> навигация: стрелка на аэропорт или город</div>\n        <div>Гонка: пролети розовое кольцо у Skyport — 13 колец через Дубай, Ташкент и Лондон</div>')
    return s


NEW_AIRPORTS = """
  { id: "C", code: "LNW", cx: -9000, cz: 15500, rot: 0, L: 4500, W: 200, south: "36", north: "18", title: "LONDON WEST",
    parked: [["A320", -400], ["A350", 420], ["LEAR75", -650]] },
  { id: "D", code: "DXC", cx: 11500, cz: -9000, rot: 0, L: 4500, W: 200, south: "36", north: "18", title: "DUBAI COAST",
    parked: [["A380", 450], ["B787", -420], ["G650", -700]] },
  { id: "E", code: "TSE", cx: 14500, cz: 6500, rot: 0, L: 4500, W: 200, south: "36", north: "18", title: "TASHKENT EAST",
    parked: [["A320", -400], ["B787", 420], ["C172", -700]] },
"""

FLOW_JS = r"""
// ===== режимы: свободный полёт, рейс (карьера), гонка колец; выбор аэропорта; стояночный тормоз
const AP_CODES = { A: "SKP", B: "MTV" };
for (const ap of AIRPORTS) ap.code = ap.code || AP_CODES[ap.id];
let gameMode = "free", flightDest = null, parkBrake = false;
function spawnFor(cfg, mode) {
  if (mode === "race") { const r = CITYDATA.rings[0], d = new V3(-Math.sin(r[4]), 0, -Math.cos(r[4])); return { pos: new V3(r[0], r[1], r[2]).addScaledVector(d, -1500), yaw: r[4], air: true }; }
  if (mode === "air") return { pos: new V3(0, 3000 / FT, 9000), yaw: 0, air: true };
  const ap = AIRPORTS.find((a) => "runway:" + a.id === mode) || AIRPORTS[0];
  const w = apToWorld(ap, 0, ap.L / 2 - 140);
  return { pos: new V3(w.x, 0.5 + cfg.gearHeight, w.z), yaw: ap.rot ? Math.PI / 2 : 0, air: false };
}
function airportAt(x, z) {
  for (const ap of AIRPORTS) {
    const dx = x - ap.cx, dz = z - ap.cz, lx = ap.rot ? -dz : dx, lz = ap.rot ? dx : dz;
    if (Math.abs(lx) < ap.W / 2 + 25 && Math.abs(lz) < ap.L / 2 + 25) return ap;
  }
  return null;
}
"""

FLOW_UI_JS = r"""
{
  for (const sel of [$("selFrom"), $("selTo")]) for (const ap of AIRPORTS) { const o = document.createElement("option"); o.value = ap.id; o.textContent = ap.code + " · " + ap.title; sel.appendChild(o); }
  $("selTo").value = "C";
  const setGM = (m) => { gameMode = m; for (const [id, v] of [["mFree", "free"], ["mCareer", "career"], ["mRace", "race"]]) $(id).setAttribute("aria-pressed", m === v);
    $("toWrap").hidden = m !== "career"; $("apRow").hidden = m === "race"; };
  $("mFree").onclick = () => setGM("free"); $("mCareer").onclick = () => setGM("career"); $("mRace").onclick = () => setGM("race");
  setGM("free");
}
function currentMode() {
  flightDest = null;
  if (gameMode === "race") return "race";
  if ($("chkAir").checked) return "air";
  if (gameMode === "career") { flightDest = $("selTo").value; if (flightDest === $("selFrom").value) flightDest = AIRPORTS.find((a) => a.id !== flightDest).id; }
  return "runway:" + $("selFrom").value;
}
"""


def add_flow(s):
    """Меню режимов, выбор аэропорта вылета/назначения, ангар по категориям, стояночный тормоз."""
    s = patch(s, '    parked: [["B737", -400], ["GL7500", -620], ["B787", 420]] },\n', '    parked: [["B737", -400], ["GL7500", -620], ["B787", 420]] },' + NEW_AIRPORTS)
    s = patch(s, '<div class="row"><span style="color:var(--dim);font-size:13px">Старт:</span>\n        <div class="seg"><button id="mRunway" aria-pressed="true">На полосе</button><button id="mAir" aria-pressed="false">В воздухе</button></div>\n      </div>',
              '<div class="row"><span style="color:var(--dim);font-size:13px">Режим:</span>\n        <div class="seg"><button id="mFree" aria-pressed="true">Свободный полёт</button><button id="mCareer" aria-pressed="false">Рейс</button><button id="mRace" aria-pressed="false">Гонка колец</button></div>\n      </div>\n'
              '      <div class="row" id="apRow"><span style="color:var(--dim);font-size:13px">Вылет:</span><select id="selFrom" class="sel"></select>'
              '<span id="toWrap" hidden><span style="color:var(--dim);font-size:13px">Назначение:</span> <select id="selTo" class="sel"></select></span>'
              '<label style="font-size:13px;color:var(--dim)"><input type="checkbox" id="chkAir"> старт в воздухе</label></div>')
    s = patch(s, ".card:hover {", ".sel { background: var(--panel-solid); color: var(--fg); border: 1px solid var(--line); border-radius: 8px; padding: 7px 8px; font: inherit; font-size: 13px; max-width: 100%; }\n.cat { grid-column: 1 / -1; font-family: var(--f-display); font-size: 15px; letter-spacing: .08em; color: var(--fg); margin-top: 6px; }\n#park { position: absolute; left: 50%; bottom: calc(210px + env(safe-area-inset-bottom, 0px)); transform: translateX(-50%); background: rgba(120,20,30,.88); border: 1px solid var(--red); border-radius: 24px; padding: 10px 18px; font-weight: 600; font-size: 14px; white-space: nowrap; }\n.card:hover {")
    s = patch(s, "  const air = mode === \"air\";\n  const pos = air ? new V3(0, 3000 / FT, 9000) : new V3(0, 0.5 + cfg.gearHeight, 2500 - 140);",
              "  const sp = spawnFor(cfg, mode), air = sp.air;\n  const pos = sp.pos;")
    s = patch(s, "return { cfg, mode, pos, att: new Q(), speed,", "return { cfg, mode, pos, att: new Q().setFromAxisAngle(AY, sp.yaw), speed,")
    s = patch(s, "vel: new V3(0, 0, -speed),", "vel: new V3(-Math.sin(sp.yaw), 0, -Math.cos(sp.yaw)).multiplyScalar(speed),")
    s = patch(s, "function newFlight(cfg, mode) {", FLOW_JS + "function newFlight(cfg, mode) {")
    # ангар по категориям
    s = patch(s, "for (const id of ORDER) {\n  const c = PLANES[id];\n  const b = document.createElement(\"button\"); b.className = \"card\";",
              "const CATS = [[\"ЛЁГКИЕ И БИЗНЕС-ДЖЕТЫ\", [\"C172\", \"LEAR75\", \"G650\", \"GL7500\"]], [\"УЗКОФЮЗЕЛЯЖНЫЕ\", [\"B737\", \"A320\"]], [\"ШИРОКОФЮЗЕЛЯЖНЫЕ\", [\"B787\", \"A330\", \"A350\", \"B747\", \"A380\"]], [\"ВОЕННЫЕ\", [\"F16\"]]];\n"
              "for (const [catName, ids] of CATS) { const h = document.createElement(\"div\"); h.className = \"cat\"; h.textContent = catName; grid.appendChild(h);\nfor (const id of ids) {\n  const c = PLANES[id];\n  const b = document.createElement(\"button\"); b.className = \"card\";")
    s = patch(s, "  b.onclick = () => startFlight(c, spawnMode);\n  grid.appendChild(b);\n}", "  b.onclick = () => startFlight(c, currentMode());\n  grid.appendChild(b);\n}}")
    s = patch(s, 'const setMode = (m) => { spawnMode = m; $("mRunway").setAttribute("aria-pressed", m === "runway"); $("mAir").setAttribute("aria-pressed", m === "air"); };\n$("mRunway").onclick = () => setMode("runway"); $("mAir").onclick = () => setMode("air");', FLOW_UI_JS)
    # старт полёта: тормоз, навигация рейса
    s = patch(s, "  lastCfg = cfg; lastMode = mode; raceReset();\n",
              "  lastCfg = cfg; lastMode = mode; raceReset();\n  parkBrake = mode.startsWith(\"runway\"); if (mode === \"race\") navIdx = 0;\n"
              "  if (flightDest) { navIdx = AIRPORTS.findIndex((a) => a.id === flightDest) + 1; setTimeout(() => { const d = AIRPORTS[navIdx - 1]; toast(\"Рейс в \" + d.code + \" · \" + d.title + \" — навигация включена\", \"var(--magenta)\"); }, 3200); }\n")
    s = patch(s, "      brakes: k(\"KeyB\") || touch.brake,", "      brakes: k(\"KeyB\") || touch.brake || (parkBrake && f.onGround),")
    s = patch(s, 'KeyN: "nav" };', 'KeyN: "nav", Space: "park" };')
    s = patch(s, '  if (a === "nav") { cycleNav(); return; }', '  if (a === "nav") { cycleNav(); return; }\n  if (a === "park") { if (flight && flight.onGround) { parkBrake = !parkBrake; toast(parkBrake ? "Стояночный тормоз включён" : "Стояночный тормоз отключён", parkBrake ? "var(--amber)" : "var(--green)"); } return; }')
    s = patch(s, '<div id="nav" hidden></div>', '<div id="nav" hidden></div>\n  <button id="park" hidden>Ⓟ Стояночный тормоз · пробел или нажми, чтобы отключить</button>')
    s = patch(s, "  drawRadar(f, hdg);\n", "  drawRadar(f, hdg);\n  if (!f.onGround) parkBrake = false;\n  $(\"park\").hidden = !parkBrake || f.crashed;\n")
    s = patch(s, '$("bNav").onclick = () => cycleNav();', '$("bNav").onclick = () => cycleNav();\n$("park").onclick = () => action("park");')
    # рейс: посадка в аэропорту назначения
    s = patch(s, "        toast(ev.text, ev.good ? \"var(--green)\" : \"var(--amber)\"); addLog(ev.text);",
              "        toast(ev.text, ev.good ? \"var(--green)\" : \"var(--amber)\"); addLog(ev.text);\n"
              "        { const ap = airportAt(f.pos.x, f.pos.z); if (flightDest && ap && ap.id === flightDest) { const d = ap; flightDest = null; setTimeout(() => toast(\"РЕЙС ВЫПОЛНЕН · \" + d.code + \" · \" + d.title, \"var(--green)\"), 2500); addLog(\"Рейс выполнен: \" + d.code); } }")
    s = patch(s, "Веб-версия Roblox-игры: та же физика, посадки и крушения. Города: Дубай (к северо-востоку от полосы), Лондон (к югу), Ташкент (к востоку). Нашли странное поведение — включите «Отладку» и скопируйте отчёт в чат.",
              "Выберите режим, аэропорт и самолёт. Рейс: посадка в аэропорту назначения. Гонка: 13 колец через Дубай, Ташкент и Лондон. Пробел — стояночный тормоз, N — навигация.")
    return s


MENU_CSS = """
#menu, #flow { z-index: 30; background: radial-gradient(1200px 700px at 20% 0%, rgba(30,50,90,.55), rgba(4,8,16,.92)); align-items: start; overflow: auto; }
.mwrap { width: min(1160px, 100%); display: grid; gap: 14px; padding-block: 56px 24px; }
.tiles { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 12px; }
.tile, .ncard, .pcard, .fprev { position: relative; border: 1px solid var(--line); border-radius: 18px; background: #0e1a30 center / cover no-repeat; overflow: hidden; color: #fff; }
.tile { min-height: 190px; padding: 18px; display: flex; flex-direction: column; align-items: flex-end; justify-content: flex-end; text-align: right; grid-column: span 2; }
.tile.big { grid-column: span 3; min-height: 250px; }
.tile::before, .ncard::before, .pcard::before, .fprev::before { content: ""; position: absolute; inset: 0; background: linear-gradient(to top left, rgba(4,8,16,.88), rgba(4,8,16,.15) 60%, rgba(4,8,16,0)); }
.tile > *, .ncard > *, .pcard > *, .fprev > * { position: relative; }
.tile .ic { margin-bottom: auto; font-size: 34px; color: #fff; opacity: .9; }
.tile b { font-family: var(--f-display); font-weight: 400; font-size: clamp(22px, 3.2vw, 38px); line-height: 1.05; text-shadow: 0 2px 14px rgba(0,0,0,.6); }
.tile small { color: #dfe8f7; text-shadow: 0 1px 8px rgba(0,0,0,.7); font-size: 13px; margin-top: 6px; max-width: 34ch; }
.tile:hover, .ncard:hover, .pcard:hover { border-color: var(--magenta); }
.mh { color: var(--dim); font-size: 13px; letter-spacing: .1em; text-transform: uppercase; border-bottom: 1px solid var(--line); padding-bottom: 6px; }
.news { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(240px, 1fr); gap: 12px; overflow-x: auto; padding-bottom: 4px; }
.ncard { min-height: 140px; padding: 14px; display: flex; flex-direction: column; justify-content: flex-end; text-align: left; }
.ncard b { font-size: 17px; }
.ncard i { font-style: normal; color: #dfe8f7; font-size: 12px; text-shadow: 0 1px 8px rgba(0,0,0,.7); }
.ncard .tag { position: absolute; top: 10px; right: 10px; background: #36b7ff; color: #041018; font-size: 11px; font-weight: 600; padding: 3px 8px; border-radius: 6px; }
.mbar { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.mbar .who { margin-left: auto; color: var(--dim); font-size: 13px; }
.flow { width: min(1180px, 100%); height: min(720px, calc(100vh - 84px)); margin-block: 56px 20px; display: grid; grid-template-columns: minmax(0, 470px) minmax(0, 1fr); gap: 16px; }
.flist { overflow: auto; display: grid; align-content: start; gap: 10px; padding-right: 6px; }
.flist h3 { margin: 10px 0 0; font-family: var(--f-display); font-weight: 400; font-size: 26px; letter-spacing: .03em; }
.pgrid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.pcard { aspect-ratio: 16 / 10; padding: 10px 12px; display: flex; align-items: flex-end; text-align: left; font-family: var(--f-display); font-size: 17px; }
.pcard[aria-pressed="true"] { border: 2px solid #fff; box-shadow: 0 0 0 4px rgba(255,255,255,.18); }
.acard { text-align: left; background: rgba(14,26,48,.85); border: 1px solid var(--line); border-radius: 16px; padding: 12px 16px; display: grid; gap: 2px; }
.acard b { font-family: var(--f-display); font-weight: 400; font-size: 30px; }
.acard span { color: var(--dim); font-size: 13px; text-transform: uppercase; letter-spacing: .04em; }
.acard[aria-pressed="true"] { background: #fff; color: #0b1324; }
.acard[aria-pressed="true"] span { color: #4b5870; }
.fprev { display: flex; flex-direction: column; justify-content: flex-end; padding: 20px; min-height: 260px; }
.fprev h2 { margin: 0; font-family: var(--f-display); font-weight: 400; font-size: clamp(26px, 4vw, 44px); }
.fprev p { margin: 4px 0 0; color: #dfe8f7; max-width: 60ch; text-shadow: 0 1px 8px rgba(0,0,0,.7); }
.fbtns { display: flex; gap: 10px; justify-content: flex-end; margin-top: 16px; flex-wrap: wrap; }
.fbtns .go { background: #2ea050; border-color: transparent; color: #fff; font-size: 16px; padding: 11px 26px; }
.fbtns .tb { font-size: 15px; padding: 11px 22px; }
@media (max-width: 760px) {
  .tile, .tile.big { grid-column: span 6; min-height: 150px; }
  .flow { grid-template-columns: 1fr; height: auto; }
  .flist { max-height: 55vh; }
}
"""

MENU_HTML = """
  <div class="overlay" id="menu">
    <div class="mwrap">
      <div class="tiles">
        <button class="tile big" data-m="free" data-ph="mode_free"><span class="ic">✈</span><b>Свободный<br>полёт</b><small>Любой самолёт, любой из 5 аэропортов</small></button>
        <button class="tile big" data-m="career" data-ph="mode_career"><span class="ic">⇄</span><b>Режим<br>рейсов</b><small>Вылет из одного аэропорта и посадка в другом</small></button>
        <button class="tile" data-m="race" data-ph="mode_race"><span class="ic">◎</span><b>Гонка колец</b><small>13 колец: Дубай → Ташкент → Лондон</small></button>
        <button class="tile" data-m="help" data-ph="news_airports"><span class="ic">⌨</span><b>Управление</b><small>Клавиши, телефон, геймпад</small></button>
        <button class="tile" data-m="spot" data-ph="news_tashkent"><span class="ic">⌖</span><b>Обзор<br>самолётов</b><small>Все 12 самолётов в ангаре</small></button>
      </div>
      <div class="mh">Что нового</div>
      <div class="news">
        <div class="ncard" data-ph="news_airports"><span class="tag">Последнее обновление</span><b>5 аэропортов и рейсы</b><i>London West, Dubai Coast, Tashkent East</i></div>
        <div class="ncard" data-ph="plane_A380"><b>Strato 320 / 330 / 350 / 380</b><i>Самолёты типа Airbus</i></div>
        <div class="ncard" data-ph="mode_race"><b>Гонка колец</b><i>Под Тауэрским мостом</i></div>
        <div class="ncard" data-ph="mode_free"><b>Дубай, Лондон, Ташкент</b><i>Бурдж-Халифа, Биг-Бен, телебашня</i></div>
      </div>
      <div class="mbar"><button class="tb primary" id="mPlay">Полёт</button><button class="tb" id="mHelp2">Клавиши</button><span class="who" id="mBest"></span></div>
    </div>
  </div>
  <div class="overlay" id="flow" hidden>
    <div class="flow">
      <div class="flist" id="fList"></div>
      <div class="fprev" id="fPrev"><h2 id="fTitle"></h2><p id="fText"></p>
        <div class="fbtns"><button class="tb" id="fMenu">Меню</button><button class="tb" id="fBack">Назад</button><button class="tb go" id="fNext">Далее →</button></div>
      </div>
    </div>
  </div>
"""

MENU_JS = r"""
// ===== главное меню с фото, ангар с фото самолётов, выбор аэропорта
const FL = { mode: "free", plane: null, from: "A", to: null, step: "planes" };
const ph = (k) => (PHOTOS[k] ? `url(${PHOTOS[k]})` : "");
document.querySelectorAll("[data-ph]").forEach((el) => (el.style.backgroundImage = ph(el.dataset.ph)));
function openMenu() {
  for (const id of ["hangar", "flow", "crash", "help"]) $(id).hidden = true;
  let best = null; try { best = parseFloat(localStorage.getItem("skypilot.bestRace")); } catch (e) {}
  $("mBest").textContent = best > 0 ? "Рекорд гонки: " + fmtT(best) : "Пилот: гость";
  $("menu").hidden = false;
}
function openFlow(mode) { FL.mode = mode; FL.step = "planes"; $("menu").hidden = true; $("flow").hidden = false; renderFlow(); }
const PLANE_TEXT = (c) => `${c.cls} · макс ${c.maxKts} kt · отрыв ${c.vrKts} kt · сваливание ${c.stallKts} kt · потолок ${c.ceilingFt.toLocaleString("ru-RU")} ft`;
function renderFlow() {
  const L = $("fList"); L.innerHTML = "";
  const prev = $("fPrev");
  if (FL.step === "planes") {
    for (const [cat, ids] of CATS) {
      const h = document.createElement("h3"); h.textContent = cat; L.appendChild(h);
      const g = document.createElement("div"); g.className = "pgrid"; L.appendChild(g);
      for (const id of ids) {
        const c = PLANES[id], b = document.createElement("button");
        b.className = "pcard"; b.style.backgroundImage = ph("plane_" + id); b.textContent = c.name; b.setAttribute("aria-pressed", FL.plane === id);
        b.onclick = () => { FL.plane = id; renderFlow(); };
        g.appendChild(b);
      }
    }
    const c = PLANES[FL.plane];
    prev.style.backgroundImage = c ? ph("plane_" + FL.plane) : ph("mode_" + (FL.mode === "race" ? "race" : FL.mode === "career" ? "career" : "free"));
    $("fTitle").textContent = c ? c.name : FL.mode === "race" ? "Гонка колец" : FL.mode === "career" ? "Режим рейсов" : "Свободный полёт";
    $("fText").textContent = c ? PLANE_TEXT(c) : "Выберите самолёт слева.";
  } else {
    const key = FL.step === "from" ? "from" : "to";
    for (const ap of AIRPORTS) {
      if (key === "to" && ap.id === FL.from) continue;
      const b = document.createElement("button"); b.className = "acard"; b.setAttribute("aria-pressed", FL[key] === ap.id);
      b.innerHTML = `<b>${ap.code} / ${ap.id}</b><span>${ap.title} · полоса ${ap.south}/${ap.north} · ${Math.round(ap.L * 0.515)} м</span>`;
      b.onclick = () => { FL[key] = ap.id; renderFlow(); };
      L.appendChild(b);
    }
    prev.style.backgroundImage = ph(FL.from === "C" || FL.to === "C" ? "news_airports" : "mode_career");
    const ap = AIRPORTS.find((a) => a.id === FL[key]);
    $("fTitle").textContent = key === "from" ? "Аэропорт вылета" : "Аэропорт назначения";
    $("fText").textContent = ap ? ap.code + " · " + ap.title : "Выберите аэропорт слева.";
  }
  const last = FL.step === "to" || (FL.step === "from" && FL.mode !== "career") || (FL.step === "planes" && FL.mode === "race");
  $("fNext").textContent = last ? "Полёт ✈" : "Далее →";
}
function flowNext() {
  if (FL.step === "planes") { if (!FL.plane) return toast("Выберите самолёт", "var(--amber)"); if (FL.mode === "race") return launchFlow(); FL.step = "from"; }
  else if (FL.step === "from") { if (FL.mode !== "career") return launchFlow(); if (FL.to === FL.from) FL.to = null; FL.step = "to"; }
  else if (FL.step === "to") { if (!FL.to) return toast("Выберите аэропорт назначения", "var(--amber)"); return launchFlow(); }
  renderFlow();
}
function launchFlow() {
  gameMode = FL.mode; flightDest = FL.mode === "career" ? FL.to : null;
  $("flow").hidden = true;
  startFlight(PLANES[FL.plane], FL.mode === "race" ? "race" : "runway:" + FL.from);
}
$("fNext").onclick = flowNext;
$("fBack").onclick = () => { if (FL.step === "to") FL.step = "from"; else if (FL.step === "from") FL.step = "planes"; else return openMenu(); renderFlow(); };
$("fMenu").onclick = openMenu;
document.querySelectorAll("#menu .tile").forEach((t) => (t.onclick = () => {
  const m = t.dataset.m;
  if (m === "help") { $("help").hidden = false; return; }
  openFlow(m === "spot" ? "free" : m);
}));
$("mPlay").onclick = () => openFlow("free");
$("mHelp2").onclick = () => { $("help").hidden = false; };
openMenu();
"""


def add_menu(s):
    """Главное меню с фото-плитками, «Что нового», ангар с фото каждого самолёта."""
    import json as _json
    photos = _json.load(open(os.path.join(ROOT, "tools", "photos.json")))
    s = patch(s, "<script>const CITYDATA = ", "<script>const PHOTOS = " + _json.dumps(photos) + ";</script>\n<script>const CITYDATA = ")
    s = patch(s, ".card:hover {", MENU_CSS + ".card:hover {")
    s = patch(s, '  <div class="overlay" id="hangar">', MENU_HTML + '  <div class="overlay" id="hangar" hidden>')
    s = patch(s, '$("bHangar").onclick = () => { $("hangar").hidden = !$("hangar").hidden; };', '$("bHangar").onclick = () => { if ($("menu").hidden && $("flow").hidden) openMenu(); else { $("menu").hidden = true; $("flow").hidden = true; } };')
    s = patch(s, '$("toHangar").onclick = () => { $("crash").hidden = true; $("hangar").hidden = false; };', '$("toHangar").onclick = () => { $("crash").hidden = true; openMenu(); };')
    s = patch(s, '  if (a === "hangar") { $("hangar").hidden = !$("hangar").hidden; return; }', '  if (a === "hangar") { $("bHangar").onclick(); return; }')
    s = patch(s, '$("loading").hidden = true;', MENU_JS + '$("loading").hidden = true;')
    s = patch(s, '<button class="tb primary" id="bHangar">✈ Ангар</button>', '<button class="tb primary" id="bHangar">✈ Меню</button>')
    s = patch(s, '$("hangar").hidden = true; $("crash").hidden = true;', '$("hangar").hidden = true; $("menu").hidden = true; $("flow").hidden = true; $("crash").hidden = true;')
    return s


TAPE_JS = r"""
// ===== шкала курса
const tapeCv = document.getElementById("htape"), tctx = tapeCv.getContext("2d");
function drawTape(hdg) {
  const W = tapeCv.width, H = tapeCv.height, ppd = W / 110;
  tctx.clearRect(0, 0, W, H);
  tctx.textAlign = "center"; tctx.textBaseline = "middle"; tctx.font = "600 26px IBM Plex Mono, monospace";
  const base = Math.floor(hdg / 5) * 5;
  for (let h = base - 60; h <= base + 60; h += 5) {
    const x = W / 2 + (h - hdg) * ppd; const big = h % 10 === 0;
    tctx.fillStyle = "rgba(142,163,196,.8)"; tctx.fillRect(x - 1.5, 0, 3, big ? 16 : 9);
    if (big && Math.abs(h - hdg) > 9.5) tctx.fillText(String(((h % 360) + 360) % 360).padStart(3, "0"), x, 42);
  }
  tctx.fillStyle = "#0e1a30"; tctx.fillRect(W / 2 - 58, 6, 116, 56);
  tctx.strokeStyle = "rgba(120,170,255,.5)"; tctx.lineWidth = 2; tctx.strokeRect(W / 2 - 58, 6, 116, 56);
  tctx.fillStyle = "#e4eeff"; tctx.font = "600 38px IBM Plex Mono, monospace"; tctx.fillText(String(Math.round(hdg) % 360).padStart(3, "0"), W / 2, 36);
  tctx.fillStyle = "#ff4fd8"; tctx.fillRect(W / 2 - 24, H - 5, 48, 5);
}
"""


def add_tape(s):
    """Шкала курса вверху (лента с делениями)."""
    s = patch(s, "#warn {", "#htape { position: absolute; top: calc(118px + env(safe-area-inset-top, 0px)); left: 50%; transform: translateX(-50%); width: min(440px, calc(100% - 140px)); height: 34px; background: var(--panel); border: 1px solid var(--line); border-radius: 8px; }\n#warn {")
    s = patch(s, "#nav { position: absolute; top: calc(122px", "#nav { position: absolute; top: calc(158px")
    s = patch(s, "#toast { position: absolute; top: calc(162px", "#toast { position: absolute; top: calc(198px")
    s = patch(s, '<div id="nav" hidden></div>', '<canvas id="htape" width="880" height="68" hidden></canvas>\n  <div id="nav" hidden></div>')
    s = patch(s, "// ============================================================ HUD\n", "// ============================================================ HUD\n" + TAPE_JS)
    s = patch(s, "  drawRadar(f, hdg);\n", "  drawRadar(f, hdg);\n  $(\"htape\").hidden = f.crashed; drawTape(hdg);\n")
    s = patch(s, '$("radar").hidden = true; $("race").hidden = true;', '$("radar").hidden = true; $("htape").hidden = true; $("race").hidden = true;')
    return s


SOUND_JS = r"""
// ===== звук двигателей: синтез в браузере (шум турбины + гул + свист), без файлов
let AC = null, SND = null, soundOn = true;
try { soundOn = localStorage.getItem("skypilot.sound") !== "off"; } catch (e) {}
function soundInit() {
  if (AC || !soundOn) return;
  const Ctx = window.AudioContext || window.webkitAudioContext; if (!Ctx) return;
  try {
    AC = new Ctx();
    const buf = AC.createBuffer(1, AC.sampleRate * 2, AC.sampleRate), d = buf.getChannelData(0);
    let last = 0; for (let i = 0; i < d.length; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; d[i] = last * 3.5; }
    const noise = AC.createBufferSource(); noise.buffer = buf; noise.loop = true;
    const band = AC.createBiquadFilter(); band.type = "bandpass"; band.Q.value = 0.7;
    const nGain = AC.createGain(); nGain.gain.value = 0;
    noise.connect(band).connect(nGain);
    const hum = AC.createOscillator(); hum.type = "sawtooth";
    const humLp = AC.createBiquadFilter(); humLp.type = "lowpass"; humLp.frequency.value = 420;
    const hGain = AC.createGain(); hGain.gain.value = 0;
    hum.connect(humLp).connect(hGain);
    const whine = AC.createOscillator(); whine.type = "sine";
    const wGain = AC.createGain(); wGain.gain.value = 0;
    whine.connect(wGain);
    const master = AC.createGain(); master.gain.value = 0.9;
    for (const g of [nGain, hGain, wGain]) g.connect(master);
    master.connect(AC.destination);
    noise.start(); hum.start(); whine.start();
    SND = { band, nGain, hum, hGain, whine, wGain, master };
  } catch (e) { AC = null; SND = null; }
}
addEventListener("pointerdown", soundInit, { capture: true });
addEventListener("keydown", soundInit, { capture: true });
function updateSound(f) {
  if (!SND) return;
  const t = AC.currentTime, on = soundOn && f && !f.crashed && !document.hidden;
  const thr = f ? (f.reverse ? 0.6 : f.throttle) : 0, prop = f && f.cfg.engines === "prop";
  const spool = 0.25 + thr * 0.75, spd = f ? Math.min(1, f.speed / f.cfg.maxKts) : 0;
  const k = (v) => (on ? v : 0);
  SND.band.frequency.setTargetAtTime(prop ? 300 + thr * 500 : 500 + thr * 1500, t, 0.3);
  SND.nGain.gain.setTargetAtTime(k(0.05 + thr * 0.22 + spd * 0.08), t, 0.25);
  SND.hum.frequency.setTargetAtTime(prop ? 38 + thr * 70 : 55 + thr * 45, t, 0.3);
  SND.hGain.gain.setTargetAtTime(k(prop ? 0.05 + thr * 0.12 : 0.02 + thr * 0.04), t, 0.25);
  SND.whine.frequency.setTargetAtTime(1400 + spool * 2600, t, 0.4);
  SND.wGain.gain.setTargetAtTime(k(prop ? 0 : 0.006 + thr * 0.018), t, 0.3);
}
function soundCrash() {
  if (!SND || !soundOn) return;
  const t = AC.currentTime;
  const src = AC.createBufferSource(); src.buffer = SND.band.context.createBuffer(1, AC.sampleRate * 2, AC.sampleRate);
  const d = src.buffer.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / d.length, 2);
  const lp = AC.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 700;
  const g = AC.createGain(); g.gain.value = 0.9; g.gain.setTargetAtTime(0, t + 0.4, 0.5);
  src.connect(lp).connect(g).connect(AC.destination); src.start();
}
function toggleSound() {
  soundOn = !soundOn; try { localStorage.setItem("skypilot.sound", soundOn ? "on" : "off"); } catch (e) {}
  $("bSnd").textContent = "Звук: " + (soundOn ? "вкл" : "выкл"); $("bSnd").setAttribute("aria-pressed", soundOn);
  if (soundOn) soundInit();
}
$("bSnd").textContent = "Звук: " + (soundOn ? "вкл" : "выкл");
"""


def add_sound(s):
    """Звук двигателей (WebAudio-синтез) и удар при крушении; кнопка «Звук»."""
    s = patch(s, '<button class="tb" id="bNav">Навигация</button>', '<button class="tb" id="bNav">Навигация</button>\n    <button class="tb" id="bSnd" aria-pressed="true">Звук: вкл</button>')
    s = patch(s, "// ============================================================ HUD\n", "// ============================================================ HUD\n" + SOUND_JS)
    s = patch(s, '$("bNav").onclick = () => cycleNav();', '$("bNav").onclick = () => cycleNav();\n$("bSnd").onclick = () => toggleSound();')
    s = patch(s, "  $(\"htape\").hidden = f.crashed; drawTape(hdg);\n", "  $(\"htape\").hidden = f.crashed; drawTape(hdg);\n  updateSound(f);\n")
    s = patch(s, "function doCrash(reason) {", "function doCrash(reason) {\n  soundCrash(); updateSound(null);")
    s = patch(s, "<div><kbd>V</kbd> камера, <kbd>M</kbd> ангар</div>", "<div><kbd>V</kbd> камера, <kbd>M</kbd> меню, кнопка «Звук» — гул двигателей</div>")
    return s


def main():
    import json
    with open(os.path.join(ROOT, "tools", "cities.json")) as f:
        data = json.load(f)
    s = open(SRC, encoding="utf-8").read()
    s = patch(s, "<title>Sky Pilot Тестовый Полигон</title>", "<title>Sky Pilot</title>")
    # самолёты типа Airbus (те же характеристики, что в PlaneConfigs.luau)
    airbus = open(os.path.join(ROOT, "tools", "airbus_planes.js"), encoding="utf-8").read()
    s = patch(s, "  F16: { name: \"Striker X\"", airbus + "  F16: { name: \"Striker X\"")
    s = patch(s, 'const ORDER = ["C172", "LEAR75", "G650", "GL7500", "B737", "B787", "B747", "F16"];',
              'const ORDER = ["C172", "LEAR75", "G650", "GL7500", "B737", "A320", "B787", "A330", "A350", "B747", "A380", "F16"];')
    s = patch(s, "<script>\n\"use strict\";\n// ============================================================ CONFIG",
              "<script>const CITYDATA = " + json.dumps(data, separators=(",", ":")) + ";</script>\n<script>\n\"use strict\";\n// ============================================================ CONFIG")
    s = patch(s, "flatRects.push({ x0: CITY.x - 950, x1: CITY.x + 950, z0: CITY.z - 950, z1: CITY.z + 950, h: 0.45 });\n", "")
    s = cut(s, "const buildings = [];", "function groundAt",
            "const buildings = [];\n"
            "for (const o of CITYDATA.obstacles) obstacles.push({ min: { x: o[0], y: o[1], z: o[2] }, max: { x: o[3], y: o[4], z: o[5] } });\n"
            "for (const p of CITYDATA.pads) flatRects.push({ x0: p[0], x1: p[1], z0: p[2], z1: p[3], h: p[4] });\n")
    s = cut(s, "// город\n{", "// вода, поля, лес, облака", CITY_RENDER)
    s = patch(s, "[CITY.x, CITY.z, 1500]", "[5500, -7500, 1700], [-4000, 12500, 1300], [10500, 3000, 1200], [5500, -9800, 3300], [-8500, 15500, 3700], [12000, -9000, 3700], [15000, 6500, 3700]")
    s = patch(s, "Тестовая копия механики Roblox-игры: та же физика, посадки и крушения.",
              "Веб-версия Roblox-игры: та же физика, посадки и крушения. Города: Дубай (к северо-востоку от полосы), Лондон (к югу), Ташкент (к востоку).")
    s = add_nav(s)
    s = add_race_radar(s)
    s = add_flow(s)
    s = add_menu(s)
    s = add_tape(s)
    s = add_sound(s)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(s)
    print("OK ->", OUT, len(s) // 1024, "KB")


if __name__ == "__main__":
    main()
