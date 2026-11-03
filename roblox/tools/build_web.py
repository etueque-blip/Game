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
const NAV = [["АЭРОПОРТ A · SKYPORT", 0, 0], ["АЭРОПОРТ B · MOUNTAIN VIEW", 14000, -16000], ["ДУБАЙ", 5500, -7500], ["ЛОНДОН", -4000, 12500], ["ТАШКЕНТ", 10500, 3000]];
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
    s = patch(s, "[CITY.x, CITY.z, 1500]", "[5500, -7500, 1700], [-4000, 12500, 1300], [10500, 3000, 1200], [5500, -9800, 3300]")
    s = patch(s, "Тестовая копия механики Roblox-игры: та же физика, посадки и крушения.",
              "Веб-версия Roblox-игры: та же физика, посадки и крушения. Города: Дубай (к северо-востоку от полосы), Лондон (к югу), Ташкент (к востоку).")
    s = add_nav(s)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(s)
    print("OK ->", OUT, len(s) // 1024, "KB")


if __name__ == "__main__":
    main()
