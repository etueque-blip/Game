"""Премиум-оформление веб-версии: тёмное стекло, небесно-голубой акцент и золото,
крупные кнопки, шрифты с кириллицей, логотип и размытое фото на фоне меню.
Применяется последним патчем в build_web.py (поверх всех стилей)."""

ACCENT = "#3ba7ff"
ACCENT_HEX = "0x3ba7ff"
ACCENT_RGB = "59,167,255"

PREMIUM_CSS = """
/* ===================== PREMIUM THEME ===================== */
:root {
  --bg: #05080f;
  --panel: rgba(12, 18, 31, 0.7);
  --panel-solid: #0d1424;
  --line: rgba(255, 255, 255, 0.12);
  --fg: #f3f6fb;
  --dim: #9aa7bb;
  --magenta: #3ba7ff;
  --accent: #3ba7ff;
  --accent-2: #1d6fe0;
  --gold: #f4c152;
  --green: #5cf0a2;
  --f-display: "Exo 2", "Arial Black", system-ui, sans-serif;
  --f-body: "Inter", system-ui, -apple-system, sans-serif;
  --f-num: "JetBrains Mono", ui-monospace, Menlo, monospace;
  --glass: linear-gradient(180deg, rgba(34, 44, 64, 0.72), rgba(11, 16, 28, 0.74));
  --shadow: 0 10px 30px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.08);
}
body { letter-spacing: .005em; }
button:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }

/* кнопки: крупнее, стекло, мягкий подъём */
.tb { background: var(--glass); border: 1px solid var(--line); border-radius: 12px; padding: 10px 17px; font-size: 14.5px; font-weight: 600;
  min-height: 42px; box-shadow: var(--shadow); backdrop-filter: blur(12px) saturate(1.3); -webkit-backdrop-filter: blur(12px) saturate(1.3);
  transition: transform .12s ease, border-color .12s ease, background .12s ease; }
.tb:hover { border-color: rgba(255, 255, 255, 0.28); transform: translateY(-1px); }
.tb:active { transform: translateY(1px); }
.tb.primary, .fbtns .go { background: linear-gradient(180deg, #56b9ff, #1d6fe0); color: #fff; border-color: rgba(255, 255, 255, 0.22);
  font-family: var(--f-display); font-weight: 700; letter-spacing: .04em; text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
  box-shadow: 0 8px 24px rgba(29, 111, 224, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.35); }
.tb[aria-pressed="true"] { border-color: var(--gold); color: var(--gold); }
#planeName { font-family: var(--f-display); font-weight: 800; font-size: 15px; letter-spacing: .08em; }

/* приборы */
.cell { background: var(--glass); border: 1px solid var(--line); border-radius: 12px; box-shadow: var(--shadow); padding: 6px 4px 5px; }
.cell .k { font-size: 10px; letter-spacing: .14em; }
.cell .v { color: #fff; font-size: clamp(16px, 4.6vw, 27px); font-weight: 700; }
#thrFill { background: linear-gradient(to top, var(--accent), transparent); opacity: .45; }
#nav, #wx, #gm, #htape, #toast, #ils, #atc { background: var(--glass); border-color: var(--line); border-radius: 12px; box-shadow: var(--shadow);
  backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); }
#nav .arrow { color: var(--gold); }
#adi { border: 2px solid rgba(255, 255, 255, 0.18); box-shadow: var(--shadow); }
#race { background: linear-gradient(180deg, #56b9ff, #1d6fe0); color: #fff; border-radius: 10px; }
#park { border-radius: 14px; background: linear-gradient(180deg, rgba(160, 30, 44, .92), rgba(110, 16, 28, .92)); box-shadow: 0 10px 30px rgba(0,0,0,.4); }

/* сенсорное управление: крупнее */
#stick { width: 150px; height: 150px; background: radial-gradient(circle, rgba(59,167,255,.12), rgba(12,18,31,.72) 70%); border: 1px solid var(--line); box-shadow: var(--shadow); }
#knob { width: 60px; height: 60px; left: 45px; top: 45px; background: linear-gradient(180deg, #6cc4ff, #1d6fe0); box-shadow: 0 0 0 5px rgba(59,167,255,.22), 0 6px 18px rgba(0,0,0,.4); }
.rb { width: 70px; height: 44px; border-radius: 12px; background: var(--glass); border: 1px solid var(--line); font-size: 13px; box-shadow: var(--shadow); }
.rb.on { background: linear-gradient(180deg, #56b9ff, #1d6fe0); color: #fff; }
#btns { grid-template-columns: repeat(2, 74px); gap: 8px; }
#btns .rb { width: 74px; height: 48px; }
#thr { width: 66px; height: 190px; border-radius: 14px; background: var(--glass); box-shadow: var(--shadow); }
#thrLevel { background: linear-gradient(to top, rgba(59,167,255,.6), rgba(59,167,255,.12)); }
#thrHandle { height: 16px; border-radius: 6px; background: linear-gradient(180deg, #fff, #cfe6ff); box-shadow: 0 2px 8px rgba(0,0,0,.4); }

/* окна */
.overlay { background: rgba(3, 6, 12, .55); }
.sheet { background: linear-gradient(180deg, rgba(26, 36, 56, .94), rgba(10, 15, 26, .96)); border-radius: 20px; box-shadow: 0 30px 80px rgba(0,0,0,.5), inset 0 1px 0 rgba(255,255,255,.08); }
.sheet h2, .fprev h2, .flist h3, .acard b, .cat, .tile b, #warn { font-family: var(--f-display); font-weight: 800; }
.gstep b { color: var(--gold); font-family: var(--f-display); font-weight: 700; }
.seg button[aria-pressed="true"] { background: linear-gradient(180deg, #56b9ff, #1d6fe0); color: #fff; }

/* меню и ангар: размытое фото на фоне */
#menu, #flow { background: #04070d; }
#menu::before, #flow::before { content: ""; position: fixed; inset: -60px; z-index: -1; background: var(--hero, none) center / cover no-repeat;
  filter: blur(22px) saturate(1.25) brightness(.55); transform: scale(1.05); }
#menu::after, #flow::after { content: ""; position: fixed; inset: 0; z-index: -1; pointer-events: none;
  background: radial-gradient(1100px 600px at 75% -10%, rgba(59,167,255,.22), transparent 60%), linear-gradient(180deg, rgba(4,7,13,.2), rgba(4,7,13,.85)); }
.mwrap { padding-block: 28px 28px; gap: 18px; }
.brand { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.brand .mark { width: 54px; height: 54px; border-radius: 16px; display: grid; place-items: center; font-size: 28px; color: #fff;
  background: linear-gradient(145deg, #6cc4ff, #1d5fd0); box-shadow: 0 10px 30px rgba(29,111,224,.5), inset 0 1px 0 rgba(255,255,255,.4); }
.brand b { display: block; font-family: var(--f-display); font-weight: 900; font-style: italic; font-size: clamp(28px, 4vw, 40px); letter-spacing: .06em; line-height: 1;
  background: linear-gradient(180deg, #ffffff, #b9d4f5); -webkit-background-clip: text; background-clip: text; color: transparent; }
.brand small { display: block; color: var(--dim); font-size: 13px; margin-top: 4px; letter-spacing: .04em; }
.brand .chip { margin-left: auto; background: var(--glass); border: 1px solid var(--line); border-radius: 999px; padding: 9px 16px; font-size: 13px; color: var(--fg); box-shadow: var(--shadow); }
.brand .chip em { font-style: normal; color: var(--gold); font-weight: 700; }
.tile, .ncard, .pcard, .fprev { border: 1px solid rgba(255,255,255,.14); border-radius: 22px; box-shadow: 0 18px 40px rgba(0,0,0,.35);
  transition: transform .18s ease, border-color .18s ease, box-shadow .18s ease; }
.tile:hover, .ncard:hover, .pcard:hover { border-color: rgba(255,255,255,.5); transform: translateY(-3px); box-shadow: 0 24px 50px rgba(0,0,0,.45), 0 0 0 1px rgba(59,167,255,.35); }
.tile::before, .ncard::before, .fprev::before { background: linear-gradient(to top, rgba(4,7,13,.92), rgba(4,7,13,.25) 55%, rgba(4,7,13,0)); }
.pcard::before { background: linear-gradient(to top, rgba(4,7,13,.95), rgba(4,7,13,.35) 45%, rgba(4,7,13,0) 70%); }
.tile .ic { width: 46px; height: 46px; border-radius: 14px; display: grid; place-items: center; font-size: 24px;
  background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.2); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); }
.tile b { letter-spacing: .01em; }
.tile.big b { font-size: clamp(26px, 3.6vw, 44px); }
.mh { color: var(--fg); font-family: var(--f-display); font-weight: 700; letter-spacing: .16em; font-size: 13px; border-bottom-color: var(--line); }
.ncard .tag { background: var(--gold); color: #1d1503; border-radius: 999px; padding: 4px 10px; font-weight: 700; }
.ncard b { font-family: var(--f-display); font-weight: 700; font-size: 18px; }
.mbar .tb { font-size: 16px; padding: 13px 26px; }
.mbar .who { color: var(--fg); background: var(--glass); border: 1px solid var(--line); border-radius: 999px; padding: 9px 16px; }
.pcard { font-family: var(--f-display); font-weight: 700; font-size: 18px; color: #fff; text-shadow: 0 2px 10px rgba(0,0,0,.8); padding: 12px 14px; }
.pcard small { display: block; font-family: var(--f-body); font-weight: 600; font-size: 11px; letter-spacing: .12em; text-transform: uppercase; color: var(--gold); margin-bottom: 2px; }
.pcard[aria-pressed="true"] { border: 2px solid var(--gold); box-shadow: 0 0 0 4px rgba(244,193,82,.25), 0 18px 40px rgba(0,0,0,.4); }
.flist h3 { font-size: 24px; letter-spacing: .1em; color: #fff; }
.acard { background: var(--glass); border-radius: 18px; box-shadow: var(--shadow); transition: transform .15s ease; }
.acard:hover { transform: translateY(-2px); border-color: rgba(255,255,255,.35); }
.acard[aria-pressed="true"] { background: linear-gradient(180deg, #ffffff, #dfe9f7); color: #0b1324; border-color: var(--gold); }
.lv { background: var(--glass); border-radius: 999px; padding: 8px 13px; font-size: 13px; }
.lv i { width: 12px; height: 12px; border-radius: 50%; }
.lv[aria-pressed="true"] { border-color: var(--gold); background: #fff; color: #0b1324; }
.fbtns .tb { font-size: 16px; padding: 13px 24px; }
.fbtns .go { font-size: 17px; padding: 13px 32px; }
.fprev { border-radius: 26px; }
.fprev h2 { font-size: clamp(30px, 4.4vw, 52px); text-shadow: 0 4px 20px rgba(0,0,0,.6); }

/* раскладка в полёте под крупные кнопки (компьютер) */
@media (min-width: 601px) {
  #hud { top: calc(62px + env(safe-area-inset-top, 0px)); width: min(680px, calc(100% - 24px)); gap: 6px; }
  #htape { top: calc(136px + env(safe-area-inset-top, 0px)); }
  #radar, #adi { top: calc(140px + env(safe-area-inset-top, 0px)); }
  #nav { top: calc(178px + env(safe-area-inset-top, 0px)); }
  #gm { top: calc(188px + env(safe-area-inset-top, 0px)); }
  #toast { top: calc(218px + env(safe-area-inset-top, 0px)); }
  #race { top: calc(244px + env(safe-area-inset-top, 0px)); }
  #ils { top: calc(256px + env(safe-area-inset-top, 0px)); }
  #wx { top: calc(276px + env(safe-area-inset-top, 0px)); }
  #debug { top: calc(292px + env(safe-area-inset-top, 0px)) !important; }
}
/* телефон: кнопки сверху чуть крупнее, сенсор крупнее */
@media (max-width: 600px) {
  #top .tb { padding: 8px 12px; font-size: 13px; min-height: 38px; border-radius: 11px; }
  #hud { top: calc(54px + env(safe-area-inset-top, 0px)); }
  #htape { top: calc(118px + env(safe-area-inset-top, 0px)); }
  #nav { top: calc(158px + env(safe-area-inset-top, 0px)); }
  #toast { top: calc(196px + env(safe-area-inset-top, 0px)); }
  #park { bottom: calc(244px + env(safe-area-inset-bottom, 0px)); }
  #atc { bottom: calc(322px + env(safe-area-inset-bottom, 0px)); }
  .brand .chip { display: none; } .brand b { white-space: nowrap; }
  .brand { flex-wrap: wrap; } .brand .mark { width: 44px; height: 44px; font-size: 22px; border-radius: 13px; }
  .brand > div { flex: 1 1 0; min-width: 0; } .brand b { font-size: 26px; }
  .pcard { font-size: 15px; } .pcard small { font-size: 9px; letter-spacing: .08em; }
  #stick { width: 132px; height: 132px; } #knob { width: 54px; height: 54px; left: 39px; top: 39px; }
  #btns { grid-template-columns: repeat(2, 62px); gap: 6px; } #btns .rb { width: 62px; height: 46px; font-size: 11px; }
  .rb { width: 62px; } #thr { width: 56px; height: 180px; }
  .mwrap { padding-block: 18px 20px; }
}

/* телефон горизонтально (низкий экран): компактные приборы сверху, управление по углам, ничего не перекрывается */
@media (max-height: 500px) {
  #top { flex-wrap: nowrap; overflow-x: auto; scrollbar-width: none; gap: 5px; }
  #top::-webkit-scrollbar { display: none; }
  #bGfx, #bDebug, #bHelp, #planeName { display: none !important; }
  #top .tb { padding: 6px 11px; font-size: 12.5px; min-height: 34px; border-radius: 10px; flex: 0 0 auto; }
  #hud { top: calc(46px + env(safe-area-inset-top, 0px)); width: min(500px, calc(100% - 260px)); gap: 4px; }
  .cell { padding: 3px 2px 3px; border-radius: 10px; }
  .cell .k { font-size: 8px; letter-spacing: .08em; } .cell .u { font-size: 8px; }
  .cell .v { font-size: 17px; line-height: 1.15; }
  #htape { top: calc(100px + env(safe-area-inset-top, 0px)); width: min(340px, calc(100% - 260px)); height: 26px; }
  #radar { top: calc(46px + env(safe-area-inset-top, 0px)); width: 88px; height: 88px; }
  #adi { top: calc(46px + env(safe-area-inset-top, 0px)) !important; width: 80px !important; height: 80px !important; }
  #gm { top: calc(134px + env(safe-area-inset-top, 0px)); right: calc(10px + env(safe-area-inset-right, 0px)); padding: 2px 8px; }
  #gm b { font-size: 15px; }
  #race { top: calc(140px + env(safe-area-inset-top, 0px)); left: calc(8px + env(safe-area-inset-left, 0px)); right: auto; }
  #nav { top: calc(132px + env(safe-area-inset-top, 0px)); font-size: 12px; max-width: calc(100% - 260px); }
  #toast { top: calc(166px + env(safe-area-inset-top, 0px)); max-width: calc(100% - 300px); font-size: 12px; }
  #ils { top: calc(200px + env(safe-area-inset-top, 0px)); font-size: 11px; }
  #wx, #debug { display: none !important; }
  #atc { bottom: calc(10px + env(safe-area-inset-bottom, 0px)); max-width: calc(100% - 420px); font-size: 11px; white-space: normal; text-align: center; }
  #park { bottom: calc(62px + env(safe-area-inset-bottom, 0px)); max-width: calc(100% - 420px); font-size: 12px; white-space: normal; text-align: center; padding: 7px 12px; }
  #touch { padding-bottom: calc(8px + env(safe-area-inset-bottom, 0px)); }
  #stick { width: 116px; height: 116px; } #knob { width: 48px; height: 48px; left: 34px; top: 34px; }
  #rudder .rb { width: 54px; height: 34px; font-size: 11px; }
  #btns { grid-template-columns: repeat(2, 58px); gap: 5px; } #btns .rb { width: 58px; height: 34px; font-size: 10.5px; }
  #thr { width: 50px; height: 150px; } #thrWrap span { font-size: 8px; }
  .mwrap { padding-block: 14px 16px; }
  .flow { height: calc(100vh - 24px); margin-block: 12px; gap: 10px; }
  .fprev { min-height: 0; padding: 12px 14px; overflow-y: auto; justify-content: flex-start; }
  .fprev h2 { font-size: 24px; } .fprev p { font-size: 12px; }
  .livrow { gap: 5px; margin-top: 8px; } .lv { padding: 5px 10px; font-size: 11.5px; }
  .fbtns { margin-top: 10px; gap: 6px; } .fbtns .tb, .fbtns .go { font-size: 13px; padding: 8px 14px; min-height: 36px; }
  .flist h3 { font-size: 18px; } .pcard { font-size: 14px; } .pcard small { font-size: 9px; }
}
"""

BRAND_HTML = """<div class="mwrap">
      <header class="brand"><span class="mark">✈</span><div><b>SKY PILOT</b><small>Авиасимулятор · 14 самолётов · 8 аэропортов · 6 городов</small></div><span class="chip" id="mChip"></span></header>
      <div class="tiles">"""

NEWS_HTML = """      <div class="news">
        <div class="ncard" data-ph="mode_race"><span class="tag">Новое</span><b>🏆 Достижения</b><i>12 целей: мягкая посадка, все аэропорты, Ас на F-16…</i></div>
        <div class="ncard" data-ph="mode_career"><b>Перегрузка G и fly-by-wire</b><i>Пределы конструкции, тряска, поломки закрылков и шасси</i></div>
        <div class="ncard" data-ph="plane_A380"><b>Boeing, Airbus, Gulfstream</b><i>14 настоящих моделей и 6 ливрей</i></div>
        <div class="ncard" data-ph="news_airports"><b>8 аэропортов</b><i>Стамбул, Эр-Рияд, Самарканд и другие</i></div>
        <div class="ncard" data-ph="mode_race"><b>Гонка колец</b><i>Под Тауэрским мостом</i></div>
      </div>"""


GAMEPAD_JS = r"""
// ===== геймпад (как в Roblox): левый стик — штурвал, R2/L2 — тяга, R1/L1 — руль, B — тормоз,
// Y — шасси, крестовина — закрылки/интерцепторы/навигация, X — реверс, L3 — стояночный тормоз, Back — камера, Start — меню
const PAD = { p: 0, r: 0, y: 0, up: false, dn: false, brake: false, prev: [], on: false };
const PAD_ONCE = { 3: "gear", 12: "flapUp", 13: "flapDn", 2: "rev", 10: "park", 14: "spoiler", 15: "nav", 0: "nav", 8: "cam", 9: "hangar" };
function padPoll() {
  const gp = (navigator.getGamepads ? [...navigator.getGamepads()] : []).find((g) => g && g.connected);
  if (!gp) { PAD.p = PAD.r = PAD.y = 0; PAD.up = PAD.dn = PAD.brake = false; return; }
  if (!PAD.on) { PAD.on = true; toast("Геймпад подключён: левый стик — штурвал, R2/L2 — тяга, L3 — стояночный тормоз"); }
  const dz = (v, d) => (Math.abs(v) < d ? 0 : Math.sign(v) * (Math.abs(v) - d) / (1 - d));
  const expo = (v) => v * (0.4 + 0.6 * v * v);
  const b = (i) => !!(gp.buttons[i] && (gp.buttons[i].pressed || gp.buttons[i].value > 0.25));
  PAD.p = expo(dz(gp.axes[1] || 0, 0.12)); PAD.r = expo(dz(gp.axes[0] || 0, 0.12));
  PAD.y = (b(5) ? 1 : 0) - (b(4) ? 1 : 0); PAD.up = b(7); PAD.dn = b(6); PAD.brake = b(1);
  for (const i in PAD_ONCE) { const now = b(+i); if (now && !PAD.prev[i]) action(PAD_ONCE[i]); PAD.prev[i] = now; }
}
"""


FACADE_JS = r"""
    facade: (() => {
      // окна по этажам из мировых координат: подходят зданиям любого размера, без текстур и UV
      const m = new THREE.MeshStandardMaterial({ metalness: 0.02, roughness: 0.86, envMap, envMapIntensity: 0.6 });
      const U = { uNight: { value: 0 } }; window.__facadeU = U;
      m.onBeforeCompile = (sh) => {
        sh.uniforms.uNight = U.uNight;
        sh.vertexShader = "varying vec3 vFP; varying vec3 vFN;\n" + sh.vertexShader.replace("#include <project_vertex>", `#include <project_vertex>
          vec4 fwp = vec4(transformed, 1.0); vec3 fn = objectNormal;
          #ifdef USE_INSTANCING
            fwp = instanceMatrix * fwp; fn = mat3(instanceMatrix) * fn;
          #endif
          vFP = (modelMatrix * fwp).xyz; vFN = normalize(mat3(modelMatrix) * fn);`);
        sh.fragmentShader = "uniform float uNight; varying vec3 vFP; varying vec3 vFN;\nfloat fh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\n" +
          sh.fragmentShader.replace("#include <color_fragment>", `#include <color_fragment>
            float side = 1.0 - step(0.5, abs(vFN.y));
            float hc = abs(vFN.x) > abs(vFN.z) ? vFP.z : vFP.x;
            float fx = fract(hc / 7.0), fy = fract((vFP.y - 0.45) / 6.5);
            float win = side * step(0.2, fx) * step(fx, 0.8) * step(0.3, fy) * step(fy, 0.82) * step(5.0, vFP.y);
            float lit = step(0.42, fh(vec2(floor(hc / 7.0), floor((vFP.y - 0.45) / 6.5))));
            diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.09, 0.13, 0.19), win * 0.82);
            diffuseColor.rgb *= 1.0 - side * (1.0 - step(0.12, fy)) * 0.18;`).replace("#include <emissivemap_fragment>", `#include <emissivemap_fragment>
            totalEmissiveRadiance += win * lit * uNight * vec3(1.0, 0.76, 0.42) * 1.1;`);
      };
      return m;
    })(),"""


LREP_CSS = """
/* отчёт о посадке */
#lrep { position: absolute; left: 50%; top: 58%; transform: translate(-50%, -50%); width: min(420px, calc(100% - 32px)); z-index: 6;
  background: var(--glass); border: 1px solid var(--line); border-radius: 20px; box-shadow: 0 24px 60px rgba(0,0,0,.45), inset 0 1px 0 rgba(255,255,255,.1);
  backdrop-filter: blur(14px) saturate(1.3); -webkit-backdrop-filter: blur(14px) saturate(1.3); padding: 14px 16px 12px; pointer-events: none;
  animation: lrepIn .35s cubic-bezier(.2,.9,.3,1.2); }
@keyframes lrepIn { from { opacity: 0; transform: translate(-50%, -40%) scale(.94); } to { opacity: 1; transform: translate(-50%, -50%) scale(1); } }
#lrep .lh { display: flex; align-items: center; gap: 10px; }
#lrep .lb { width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; font-size: 20px; color: #fff; flex: 0 0 auto; }
#lrep .lt { font-family: var(--f-display); font-weight: 800; font-size: 22px; line-height: 1.1; }
#lrep .ls { color: var(--dim); font-size: 12px; letter-spacing: .06em; text-transform: uppercase; }
#lrep .lg { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 6px; margin-top: 12px; }
#lrep .lg div { background: rgba(255,255,255,.05); border: 1px solid var(--line); border-radius: 12px; padding: 6px 4px; text-align: center; min-width: 0; }
#lrep .lg b { display: block; font-family: var(--f-num); font-size: 18px; color: #fff; }
#lrep .lg small { display: block; font-size: 9px; letter-spacing: .1em; color: var(--dim); text-transform: uppercase; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
#lrep .lp { margin-top: 10px; display: flex; justify-content: space-between; align-items: center; font-size: 13px; color: var(--dim); }
#lrep .lp em { font-style: normal; font-family: var(--f-display); font-weight: 800; font-size: 20px; color: var(--gold); }
@media (max-height: 500px) { #lrep { top: 62%; width: min(380px, calc(100% - 300px)); padding: 10px 12px; } #lrep .lt { font-size: 18px; } #lrep .lg b { font-size: 15px; } }
"""

LREP_JS = r"""
// ===== отчёт о посадке: оценка, вертикальная, скорость, перегрузка, отклонение от оси, очки
let lrepT = null;
function showLandingReport(f, ap, text, pts) {
  const fpm = (/(\d+) fpm/.exec(text) || [0, 0])[1] | 0;
  const grade = text.startsWith("Идеальная") ? ["Идеальная посадка", "#22c07a", "★"] : text.startsWith("Хорошая") ? ["Хорошая посадка", "#3ba7ff", "✓"] : ["Жёсткая посадка", "#f0a531", "!"];
  let off = null;
  if (ap) { const dx = f.pos.x - ap.cx, dz = f.pos.z - ap.cz; off = Math.abs(ap.rot ? -dz : dx) * 0.515; }
  const paxBonus = COMF.pax > 0 && ap && flightDest && ap.id === flightDest ? Math.floor(COMF.v * 5) : 0;
  if (paxBonus > 0) setTimeout(() => addScore(paxBonus, "комфорт пассажиров"), 1500);
  const el = $("lrep");
  el.innerHTML = `<div class="lh"><span class="lb" style="background:${grade[1]}">${grade[2]}</span><div><div class="lt">${grade[0]}</div>` +
    `<div class="ls">${ap ? ap.code + " · полоса" : "вне аэропорта"}${f.damage > 0.3 ? " · есть повреждения" : ""}</div></div></div>` +
    `<div class="lg"><div><b>${fpm}</b><small>fpm</small></div><div><b>${Math.round(f.speed)}</b><small>kt</small></div>` +
    `<div><b>${f.gload.toFixed(1)}</b><small>G</small></div><div><b>${off === null ? "—" : off.toFixed(off < 10 ? 1 : 0)}</b><small>м от оси</small></div></div>` +
    `<div class="lp"><span>${COMF.pax > 0 ? `Пассажиры ${paxStars(COMF.v)}${paxBonus ? ` · +${paxBonus} за комфорт` : ""}` : off !== null && off < 5 ? "Точно по оси!" : off !== null && off > 25 ? "Далеко от оси полосы" : "Посадка засчитана"}</span>${pts + paxBonus ? `<em>+${pts + paxBonus}</em>` : ""}</div>`;
  el.hidden = false; el.style.animation = "none"; void el.offsetWidth; el.style.animation = "";
  clearTimeout(lrepT); lrepT = setTimeout(() => (el.hidden = true), 6500);
}
"""


ACH_CSS = """
/* достижения */
#achO { z-index: 40; }
.achg { display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 8px; }
.achc { display: grid; grid-template-columns: 44px 1fr; gap: 2px 10px; align-items: center; background: rgba(255,255,255,.04); border: 1px solid var(--line);
  border-radius: 14px; padding: 10px 12px; }
.achc .ai { grid-row: span 3; width: 44px; height: 44px; border-radius: 12px; display: grid; place-items: center; font-size: 24px; background: rgba(255,255,255,.06); }
.achc b { font-size: 14px; } .achc small { color: var(--dim); font-size: 11.5px; line-height: 1.3; } .achc em { font-style: normal; color: var(--gold); font-weight: 700; font-size: 12px; }
.achc.on { border: 2px solid var(--gold); background: linear-gradient(180deg, rgba(244,193,82,.12), rgba(244,193,82,.03)); }
.achc:not(.on) .ai { filter: grayscale(1); opacity: .45; } .achc:not(.on) b { color: var(--dim); }
.achbar { height: 8px; border-radius: 99px; background: rgba(255,255,255,.08); overflow: hidden; }
.achbar i { display: block; height: 100%; background: linear-gradient(90deg, var(--gold), #ffe29a); }
"""

ACH_HTML = """  <div class="overlay" id="achO" hidden>
    <div class="sheet">
      <h2>🏆 Достижения</h2>
      <p id="achSub"></p>
      <div class="achbar"><i id="achBar"></i></div>
      <div class="achg" id="achG"></div>
      <div class="row"><button class="tb primary" id="achClose">Понятно</button></div>
    </div>
  </div>
"""

ACH_JS = r"""
// ===== достижения (тот же список, что src/shared/Achievements.luau); хранятся в браузере
const ACH = [
  ["first_flight", "✈", "Первый полёт", "Оторвись от полосы", 100], ["soft", "🪶", "Мягкая посадка", "Сядь мягче 250 ft/min", 200],
  ["butter", "🧈", "Как по маслу", "Сядь мягче 80 ft/min", 500], ["center", "🎯", "Точно по оси", "Сядь не дальше 2 м от оси полосы", 300],
  ["route", "🧳", "Рейс выполнен", "Долети до аэропорта назначения в режиме рейсов", 500], ["ten", "🔟", "Десять посадок", "Соверши 10 посадок", 500],
  ["airports", "🌍", "Все аэропорты", "Сядь во всех 8 аэропортах", 2000], ["high", "🛰", "Стратосфера", "Поднимись выше 35 000 ft", 300],
  ["night", "🌙", "Ночной пилот", "Посади самолёт ночью", 400], ["race", "🏁", "Гонщик", "Пройди все кольца гонки", 500],
  ["ace", "⚡", "Ас", "Выдержи 8 G на F-16", 400], ["heavy", "🐘", "Тяжеловес", "Посади Airbus A380 или Boeing 747", 300],
];
const ACHS = (() => { try { const d = JSON.parse(localStorage.getItem("skypilot.ach") || "{}"); return { ids: d.ids || [], visited: d.visited || [] }; } catch (e) { return { ids: [], visited: [] }; } })();
function achSave() { try { localStorage.setItem("skypilot.ach", JSON.stringify(ACHS)); } catch (e) {} }
function achUnlock(id) {
  if (ACHS.ids.includes(id)) return;
  const a = ACH.find((x) => x[0] === id); if (!a) return;
  ACHS.ids.push(id); achSave();
  setTimeout(() => { toast(`🏆 Достижение «${a[2]}» · +${a[4]}`, "var(--gold)"); addScore(a[4], "достижение"); }, 900);
  achRender();
}
function achLanding(f, ap, text) {
  if (!ap) return;
  const fpm = (/(\d+) fpm/.exec(text) || [0, 999])[1] | 0;
  if (fpm < 250) achUnlock("soft");
  if (fpm < 80) achUnlock("butter");
  const dx = f.pos.x - ap.cx, dz = f.pos.z - ap.cz; if (Math.abs(ap.rot ? -dz : dx) * 0.515 < 2) achUnlock("center");
  if (flightDest && ap.id === flightDest) achUnlock("route");
  if (!ACHS.visited.includes(ap.id)) { ACHS.visited.push(ap.id); achSave(); }
  if (ACHS.visited.length >= AIRPORTS.length) achUnlock("airports");
  if (SCORE.landings >= 10) achUnlock("ten");
  if (gameClock < 5.5 || gameClock > 19.5) achUnlock("night");
  if (f.cfg.id === "A380" || f.cfg.id === "B747") achUnlock("heavy");
}
function achFrame(f) {
  if (f.pos.y * FT > 35000) achUnlock("high");
  if (f.cfg.id === "F16" && f.gload >= 8 && (f.damage || 0) < 0.05) achUnlock("ace");
}
function achRender() {
  const n = ACHS.ids.length, total = ACH.reduce((s, a) => s + a[4], 0);
  const b = document.getElementById("mAch"); if (b) b.textContent = `🏆 Достижения ${n}/${ACH.length}`;
  const g = document.getElementById("achG"); if (!g) return;
  g.innerHTML = ACH.map(([id, ic, t, d, r]) => { const on = ACHS.ids.includes(id);
    return `<div class="achc${on ? " on" : ""}"><span class="ai">${on ? ic : "🔒"}</span><b>${t}</b><small>${d}</small><em>+${r}</em></div>`; }).join("");
  $("achSub").textContent = `Открыто ${n} из ${ACH.length} · награды до +${total.toLocaleString("ru-RU")} очков · аэропортов посещено: ${ACHS.visited.length}/${AIRPORTS.length}`;
  $("achBar").style.width = (n / ACH.length * 100).toFixed(1) + "%";
}
"""


APRON_JS = r"""  // телетрапы: ротонда на колонне, телескопические секции с окнами, кабина, гармошка к двери, опора на колёсах
  const jw = std(0xc4c9d0, { metal: 0.55, rough: 0.35 }), jd = std(0x464c56, { metal: 0.5, rough: 0.5 }), wheelM = std(0x18181a, { rough: 0.9 });
  const jg = new THREE.MeshStandardMaterial({ color: lin(0x223448), metalness: 0.9, roughness: 0.1, envMap });
  const cylV = (r, h, m, x, y, z) => mesh(grp, new THREE.CylinderGeometry(r, r, h, 20), m, x, y, z, true);
  const wheelZ = (x, z, r) => { const g = new THREE.CylinderGeometry(r, r, 1, 14).rotateX(Math.PI / 2); mesh(grp, g, wheelM, x, r, z); };
  for (const [id, z] of ap.parked) {
    const c = PLANES[id]; if (!c.windows || c.length < 100) continue;
    const doorX = W / 2 + 760 - c.length * 0.12, zb = z - c.diameter * 0.5 - 6, y = 0.5 + c.gearHeight + c.diameter * 0.1, xR = tx - 84;
    cylV(3, y, jd, xR, y / 2, zb); cylV(7.5, 11, jw, xR, y + 1, zb);
    box(14, 8, 8, jw, (xR + tx - 70) / 2, y + 1, zb, true);
    const x0 = xR - 7, x1 = doorX + 7, len = x0 - x1;
    for (let k = 0; k < 3; k++) {
      const a = x0 - len * k / 3, b = x0 - len * (k + 1) / 3 - (k < 2 ? 2 : 0), sz = 9 - k * 0.6;
      box(a - b, sz, sz, jw, (a + b) / 2, y + 1, zb, true); box(a - b - 1, 2, sz + 0.2, jg, (a + b) / 2, y + 2, zb);
    }
    box(12, 10, 12, jw, doorX + 2, y + 1.5, zb + 2, true); box(10, 3, 12.2, jg, doorX + 2, y + 3, zb + 2);
    box(9, 8, 3, jd, doorX, y + 1, zb + 9);
    const legX = x1 + len * 0.3;
    for (const dz of [-3, 3]) box(1.4, y - 2, 1.4, jd, legX, (y - 2) / 2 + 1.5, zb + dz);
    box(3, 1.4, 9, jd, legX, 1.5, zb); for (const dz of [-4, 4]) wheelZ(legX, zb + dz, 1.5);
  }
  // служебные машины: буксир у носа, багажный тягач с тележками, топливозаправщик под крылом
  const yel = std(0xf2be28, { rough: 0.45 }), cabG = std(0x283038, { metal: 0.6, rough: 0.2 }), truckW = std(0xeceef0, { metal: 0.3, rough: 0.35 }), redS = std(0xc82828, { rough: 0.5 });
  const wheels4 = (x, z, lx, w) => { for (const dx of [-lx / 2 + 1.4, lx / 2 - 1.4]) for (const dz of [-w / 2, w / 2]) wheelZ(x + dx, z + dz, 1.2); };
  const bagC = [std(0x3a4a6e, { rough: 0.8 }), std(0x8c3c32, { rough: 0.8 }), std(0x46464c, { rough: 0.8 })];
  for (const [id, z] of ap.parked) {
    const c = PLANES[id], noseX = W / 2 + 760;
    box(10, 2.6, 6, yel, noseX + 8, 1.8, z, true); box(3, 2, 5, cabG, noseX + 11, 4, z); wheels4(noseX + 8, z, 10, 6.2);
    if (!c.windows || c.length < 100) continue;
    const bx = noseX - c.length * 0.72, bz = z + c.diameter * 0.5 + 10;
    box(7, 3, 5, yel, bx, 2, bz, true); box(3, 2.5, 5, cabG, bx + 1.5, 4.6, bz); wheels4(bx, bz, 7, 5.2);
    for (let k = 1; k <= 3; k++) { const cx = bx - 3 - k * 8; box(6.5, 0.6, 5, std(0x787e86, { metal: 0.6 }), cx, 1.8, bz); box(5.5, 2.4, 4.2, bagC[k - 1], cx, 3.3, bz, true); wheels4(cx, bz, 6.5, 4.6); }
    const fx = noseX - c.length * 0.45, fz = z + c.span * 0.3;
    box(6, 5, 7, truckW, fx + 11, 3.2, fz, true); box(2, 2.2, 6.4, cabG, fx + 13.6, 4.4, fz);
    mesh(grp, new THREE.CylinderGeometry(3.5, 3.5, 18, 20).rotateZ(Math.PI / 2), truckW, fx - 1, 4.6, fz, true);
    box(18, 0.8, 7.2, redS, fx - 1, 3.6, fz); wheels4(fx + 4, fz, 26, 6.4);
  }
  // мачты освещения перрона: лампы светятся ночью (dayNight)
  const poolMat = window.__poolMat || (window.__poolMat = new THREE.MeshBasicMaterial({ map: puffTex, color: lin(0xffc98a), transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending }));
  const lampMat = window.__lampMat || (window.__lampMat = new THREE.MeshStandardMaterial({ color: lin(0xfff0d0), emissive: lin(0xffe2b4), emissiveIntensity: 0, roughness: 0.4 }));
  for (const mz of [-900, -300, 300, 900]) {
    const mx = W / 2 + 300;
    box(2.4, 70, 2.4, std(0x969ca4, { metal: 0.7, rough: 0.35 }), mx, 35, mz, true); box(4, 2, 18, jd, mx + 1, 70, mz);
    for (const dz of [-6, 0, 6]) box(4, 2, 5, lampMat, mx + 2.5, 68.8, mz + dz);
    const pool = mesh(grp, new THREE.CircleGeometry(95, 40), poolMat, mx + 60, 0.62, mz); pool.rotation.x = -Math.PI / 2;
  }
"""


SPEC_CSS = """
/* ангар: характеристики */
.spec { display: grid; gap: 10px; margin-top: 8px; max-width: 520px; text-shadow: none; }
.spec .sc { display: flex; gap: 6px; flex-wrap: wrap; }
.spec .chip { background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.2); border-radius: 999px; padding: 4px 10px; font-size: 12px; color: #fff; backdrop-filter: blur(6px); }
.spec .chip.fbw { background: rgba(59,167,255,.25); border-color: rgba(59,167,255,.6); }
.spec .bars { display: grid; grid-template-columns: auto 1fr auto; gap: 6px 10px; align-items: center; font-size: 12px; color: #dfe8f7;
  background: rgba(6,10,18,.55); border: 1px solid rgba(255,255,255,.12); border-radius: 14px; padding: 10px 12px; backdrop-filter: blur(8px); }
.spec .bar { height: 7px; border-radius: 99px; background: rgba(255,255,255,.12); overflow: hidden; }
.spec .bar i { display: block; height: 100%; border-radius: 99px; background: linear-gradient(90deg, #3ba7ff, #8fd3ff); }
.spec .bars b { font-family: var(--f-num); font-weight: 600; color: #fff; font-size: 12px; text-align: right; }
.spec .nums { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 6px; }
.spec .nums div { background: rgba(6,10,18,.55); border: 1px solid rgba(255,255,255,.12); border-radius: 12px; padding: 6px 4px; text-align: center; backdrop-filter: blur(8px); }
.spec .nums b { display: block; font-family: var(--f-num); font-size: 16px; color: #fff; }
.spec .nums small { display: block; font-size: 9.5px; letter-spacing: .08em; text-transform: uppercase; color: var(--dim); }
@media (max-height: 500px) { .spec .bars { padding: 6px 10px; gap: 3px 8px; } .spec .nums b { font-size: 13px; } }
"""

SPEC_JS = r"""
// ===== характеристики самолёта для ангара (полосы относительно лучшего в игре)
function specHTML(c) {
  const all = Object.values(PLANES), mx = (k) => Math.max(...all.map((p) => p[k] || 0));
  const [gx, , fbw] = gLimits(c), vapp = Math.round(c.stallKts * (c.noFlaps ? 1 : 0.79) * 1.3 / 5) * 5;
  const bar = (label, v, m, txt) => `<span>${label}</span><span class="bar"><i style="width:${Math.max(6, Math.min(100, v / m * 100)).toFixed(0)}%"></i></span><b>${txt}</b>`;
  return `<div class="spec"><div class="sc"><span class="chip">${c.cls}</span>${fbw ? '<span class="chip fbw">Fly-by-wire</span>' : ""}${c.engines === "wing4" ? '<span class="chip">4 двигателя</span>' : ""}</div>` +
    `<div class="bars">${bar("Скорость", c.maxKts, mx("maxKts"), c.maxKts + " kt")}${bar("Потолок", c.ceilingFt, mx("ceilingFt"), (c.ceilingFt / 1000).toFixed(0) + " тыс. ft")}` +
    `${bar("Манёвренность", Math.sqrt(c.rollRate), Math.sqrt(mx("rollRate")), (Math.sqrt(c.rollRate / mx("rollRate")) * 10).toFixed(1) + "/10")}${bar("Размер", c.length, mx("length"), Math.round(c.length * 0.515) + " м")}</div>` +
    `<div class="nums"><div><b>${c.vrKts}</b><small>отрыв, kt</small></div><div><b>${vapp}</b><small>заход, kt</small></div>` +
    `<div><b>${c.stallKts}</b><small>сваливание</small></div><div><b>+${gx.toFixed(1)}</b><small>предел G</small></div></div></div>`;
}
"""


WIND_JS = r"""
// ===== ветер (как в Roblox): плавно меняется, порывы; сносит самолёт в воздухе
const WIND = { dir: Math.random() * 360, kts: 3 + Math.random() * 9, tDir: 0, tKts: 0, nextAt: 0, t: 0 };
WIND.tDir = WIND.dir; WIND.tKts = WIND.kts;
function windStep(dt) {
  WIND.t += dt;
  if (WIND.t > WIND.nextAt) { WIND.tDir = (WIND.dir + (Math.random() * 140 - 70) + 360) % 360; WIND.tKts = Math.floor(Math.pow(Math.random(), 1.6) * 25); WIND.nextAt = WIND.t + 300 + Math.random() * 300; }
  const dd = ((WIND.tDir - WIND.dir + 540) % 360) - 180;
  WIND.dir = (WIND.dir + clamp(dd, -0.4 * dt, 0.4 * dt) + 360) % 360; WIND.kts += clamp(WIND.tKts - WIND.kts, -0.04 * dt, 0.04 * dt);
}
function windVec() {
  const g = 1 + 0.25 * Math.sin(WIND.t * 0.9) * Math.sin(WIND.t * 0.37 + 1), d = WIND.dir * Math.PI / 180;
  return new V3(-Math.sin(d), 0, Math.cos(d)).multiplyScalar(WIND.kts * g);
}
function windPhrase(rw) {
  if (WIND.kts < 2) return "Ветер штиль.";
  const cross = Math.abs(WIND.kts * Math.sin((WIND.dir - (parseInt(rw, 10) || 36) * 10) * Math.PI / 180));
  return `Ветер ${String(Math.round(WIND.dir)).padStart(3, "0")}°, ${Math.round(WIND.kts)} kt, боковой ${Math.round(cross)} kt.`;
}
"""


FAN_JS = r"""    const back = add(body, new THREE.CircleGeometry(eD * 0.43, 24), darkMat); back.position.copy(p).add(new V3(0, 0, -eL / 2 + 0.45)); back.rotation.y = Math.PI;
    const rotor = new THREE.Group(); rotor.position.copy(p).add(new V3(0, 0, -eL / 2 + 0.3)); body.add(rotor);
    const bladeMat = window.__bladeMat || (window.__bladeMat = std(0x8c939c, { metal: 0.85, rough: 0.28 }));
    for (let i = 0; i < 18; i++) {
      const a = i / 18 * Math.PI * 2, bl = new THREE.Mesh(new THREE.BoxGeometry(eD * 0.075, eD * 0.3, 0.12), bladeMat);
      bl.position.set(Math.cos(a) * eD * 0.27, Math.sin(a) * eD * 0.27, 0); bl.rotation.z = a - Math.PI / 2; bl.rotateY(0.55); rotor.add(bl);
    }
    const spin = new THREE.Mesh(new THREE.ConeGeometry(eD * 0.13, eD * 0.32, 18).rotateX(-Math.PI / 2), strutMat); spin.position.z = -eD * 0.1; rotor.add(spin);
    const swirl = new THREE.Mesh(new THREE.BoxGeometry(eD * 0.035, eD * 0.09, eD * 0.2), std(0xffffff, { rough: 0.4 })); swirl.position.set(eD * 0.045, 0, -eD * 0.12); swirl.rotation.y = -0.35; rotor.add(swirl);
    (root.userData.fans || (root.userData.fans = [])).push(rotor);
    const lipM = window.__lipMat || (window.__lipMat = std(0xe8ebef, { metal: 0.95, rough: 0.12 }));
    const lip = add(body, new THREE.TorusGeometry(eD * 0.47, eD * 0.045, 10, 32), lipM); lip.position.copy(p).add(new V3(0, 0, -eL / 2 + 0.05));
    if (cfg.id === "B787") for (let i = 0; i < 14; i++) {
      const a = i / 14 * Math.PI * 2, ch = new THREE.Mesh(new THREE.ConeGeometry(eD * 0.06, eD * 0.16, 3).rotateX(Math.PI / 2), engMat);
      ch.position.copy(p).add(new V3(Math.cos(a) * eD * 0.335, Math.sin(a) * eD * 0.335, eL / 2 + eD * 0.06)); body.add(ch);
    }
"""


WATER_JS = r"""// вода: рябь из нескольких бегущих волн по мировым координатам (для горизонтальной глади)
const WATER_U = { uTime: { value: 0 } };
function waveWater(m) {
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = WATER_U.uTime;
    sh.vertexShader = "varying vec3 vWWP;\n" + sh.vertexShader.replace("#include <project_vertex>", `#include <project_vertex>
      vec4 wwp = vec4(transformed, 1.0);
      #ifdef USE_INSTANCING
        wwp = instanceMatrix * wwp;
      #endif
      vWWP = (modelMatrix * wwp).xyz;`);
    sh.fragmentShader = "uniform float uTime; varying vec3 vWWP;\n" + sh.fragmentShader.replace("#include <normal_fragment_begin>", `#include <normal_fragment_begin>
      vec2 wp = vWWP.xz; float wt = uTime; vec2 g = vec2(0.0);
      float wd = length(vWWP - cameraPosition), far1 = clamp(1.0 - wd / 900.0, 0.0, 1.0), far2 = clamp(1.0 - wd / 3500.0, 0.0, 1.0);
      g += vec2(cos(wp.x * 0.045 + wt * 1.1), cos(wp.y * 0.05 + wt * 0.9)) * 0.5;
      g += vec2(cos((wp.x + wp.y) * 0.11 - wt * 1.7), cos((wp.x - wp.y) * 0.13 + wt * 1.3)) * 0.28 * far2;
      g += vec2(cos(wp.x * 0.31 + wp.y * 0.07 + wt * 2.3), cos(wp.y * 0.29 - wp.x * 0.05 + wt * 2.1)) * 0.12 * far1;
      float amp = 0.16 * (0.25 + 0.75 * far2);
      vec3 wn = normalize(vec3(-g.x * amp, 1.0, -g.y * amp));
      normal = normalize((viewMatrix * vec4(wn, 0.0)).xyz);`).replace("#include <color_fragment>", `#include <color_fragment>
      diffuseColor.rgb *= 0.9 + 0.18 * sin(vWWP.x * 0.0021 + vWWP.z * 0.0017);`);
  };
  return m;
}
"""


ALS_JS = r"""    // огни подхода: 30 стоек через 30 stud (900 stud), по 5 огней; поперечины на 300 и 600; красные боковые ряды у торца
    for (let k = 1; k <= 30; k++) {
      const z = e * (L / 2 + 30 * k);
      for (let i = -2; i <= 2; i++) white.push({ x: i * 4, y: 3, z, sx: 2, sy: 1.4, sz: 2 });
      poles.push({ x: 0, y: 1.4, z, sx: 0.8, sy: 2.8, sz: 0.8 }); poles.push({ x: 0, y: 2.2, z, sx: 18, sy: 0.5, sz: 0.5 });
      if (k <= 10) for (const s2 of [-1, 1]) for (let i = 0; i < 3; i++) red.push({ x: s2 * (22 + i * 4), y: 3, z, sx: 2, sy: 1.4, sz: 2 });
      if (k > 10) rabbit.push({ x: 0, y: 4.4, z, sx: 3.4, sy: 2.6, sz: 3.4, seq: 30 - k, end: e });
    }
    for (const zc of [300, 600]) for (let x = -66; x <= 66; x += 6) if (Math.abs(x) > 12) white.push({ x, y: 3, z: e * (L / 2 + zc), sx: 2, sy: 1.4, sz: 2 });
"""

TAXI_BLUE_JS = r"""
  // синие огни по краям рулёжек
  for (let z = -L / 2; z <= L / 2; z += 60) for (const s of [-1, 1]) blue.push({ x: W / 2 + 250 + s * 31, y: 0.6, z, sx: 1.4, sy: 1.2, sz: 1.4 });
  for (const zc of [-L / 2 + 150, 0, L / 2 - 150]) for (let x = W / 2 + 20; x <= W / 2 + 215; x += 40) for (const s of [-1, 1]) blue.push({ x, y: 0.6, z: zc + s * 31, sx: 1.4, sy: 1.2, sz: 1.4 });"""

ALS_INST_JS = r"""
  instanced(new THREE.BoxGeometry(1, 1, 1), basic(0x3a6cff), toW(blue));
  instanced(new THREE.BoxGeometry(1, 1, 1), std(0x50545c, { metal: 0.6, rough: 0.5 }), toW(poles));
  { const items = toW(rabbit), im = instanced(new THREE.BoxGeometry(1, 1, 1), basic(0xffffff), items); RABBITS.push({ im, items }); }"""

RABBIT_JS = r"""// бегущие вспышки огней подхода («кролик»): дважды в секунду от дальнего огня к полосе
const RABBITS = [];
let rabbitT = 0;
function rabbitStep(dt) {
  rabbitT += dt; const active = Math.floor((rabbitT * 2 % 1) * 20);
  const m = new THREE.Matrix4(), q = new Q(), p = new V3(), sc = new V3();
  for (const r of RABBITS) {
    r.items.forEach((it, i) => { const on = it.seq === active; p.set(it.x, it.y, it.z); sc.set(on ? it.sx : 0.001, on ? it.sy : 0.001, on ? it.sz : 0.001); q.setFromAxisAngle(AY, it.ry || 0); m.compose(p, q, sc); r.im.setMatrixAt(i, m); });
    r.im.instanceMatrix.needsUpdate = true;
  }
}
"""


CRASH_CSS = """
/* экран крушения: отчёт о полёте */
.cstats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
.cstats div { background: rgba(255,255,255,.05); border: 1px solid var(--line); border-radius: 12px; padding: 8px 4px; text-align: center; min-width: 0; }
.cstats b { display: block; font-family: var(--f-num); font-size: 17px; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cstats small { display: block; font-size: 9.5px; letter-spacing: .1em; color: var(--dim); text-transform: uppercase; }
.ctip { background: rgba(244,193,82,.12); border: 1px solid rgba(244,193,82,.45); border-radius: 12px; padding: 10px 12px; font-size: 14px; line-height: 1.45; }
.ctip b { color: var(--gold); }
@media (max-width: 600px) { .cstats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
"""

CRASH_JS = r"""
// ===== статистика полёта и совет после крушения (как Guide.crashTip в Roblox)
const FST = { time: 0, dist: 0, maxAlt: 0, maxKts: 0, maxG: 1, landings: 0, startPts: 0, plane: "", lx: null, lz: 0 };
function fstatsReset(cfg) { Object.assign(FST, { time: 0, dist: 0, maxAlt: 0, maxKts: 0, maxG: 1, landings: 0, startPts: SCORE.points, plane: cfg.name, lx: null, lz: 0 }); }
function fstatsFrame(f, dt) {
  if (!f.onGround) FST.time += dt;
  if (FST.lx !== null) FST.dist += Math.hypot(f.pos.x - FST.lx, f.pos.z - FST.lz);
  FST.lx = f.pos.x; FST.lz = f.pos.z;
  FST.maxAlt = Math.max(FST.maxAlt, f.pos.y * FT); FST.maxKts = Math.max(FST.maxKts, f.speed); FST.maxG = Math.max(FST.maxG, f.gload || 1);
}
function crashTip(reason) {
  const r = reason.toLowerCase(), has = (w) => r.includes(w);
  if (has("без шасси")) return "Выпусти шасси (G) заранее — примерно на 1500 ft, когда скорость ниже 270 kt.";
  if (has("жёсткая")) return "Перед касанием вертикальная должна быть меньше 600 ft/min: у самой земли убери тягу (Z) и плавно подними нос.";
  if (has("крылом")) return "Касайся полосы с ровными крыльями: крен не больше 5–10°, нос чуть выше горизонта.";
  if (has("перегрузка") || has("ограничения")) return "Тяни штурвал плавнее и следи за индикатором G справа; не превышай максимальную скорость.";
  if (has("здани") || has("земл") || has("гор")) return "Держи высоту над городами и горами; при «PULL UP» сразу тяни на себя и добавь тягу.";
  if (has("край")) return "Не улетай за край карты: радар и навигация (N) покажут аэропорты.";
  return "Открой «Инструкцию» (I): там скорости взлёта, захода и пределы этого самолёта.";
}
function fillCrash() {
  const t = Math.floor(FST.time), cell = (v, k) => `<div><b>${v}</b><small>${k}</small></div>`;
  $("cStats").innerHTML = cell(`${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`, "в воздухе") + cell((FST.dist * 0.515 / 1000).toFixed(1) + " км", "пройдено") +
    cell(Math.round(FST.maxAlt).toLocaleString("ru-RU") + " ft", "макс. высота") + cell(Math.round(FST.maxKts) + " kt", "макс. скорость") +
    cell(FST.maxG.toFixed(1), "макс. G") + cell(FST.landings, "посадок") + cell("+" + Math.max(0, SCORE.points - FST.startPts), "очки") + `<div><b style="font-size:12px;white-space:normal;line-height:1.25">${FST.plane || "—"}</b><small>самолёт</small></div>`;
  $("cTip").innerHTML = "<b>Совет:</b> " + crashTip($("crashReason").textContent || "");
}
"""


PAX_CSS = """
#pax { position: absolute; right: calc(110px + env(safe-area-inset-right, 0px)); top: calc(236px + env(safe-area-inset-top, 0px)); background: var(--glass); border: 1px solid var(--line);
  border-radius: 12px; padding: 3px 10px; text-align: center; font-family: var(--f-num); box-shadow: var(--shadow); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); }
#pax b { display: block; font-size: 15px; } #pax small { display: block; font-size: 9.5px; color: var(--dim); letter-spacing: .06em; }
@media (max-width: 600px) { #pax { right: calc(92px + env(safe-area-inset-right, 0px)); top: calc(318px + env(safe-area-inset-top, 0px)); } }
@media (max-height: 500px) { #pax { right: calc(10px + env(safe-area-inset-right, 0px)); top: calc(178px + env(safe-area-inset-top, 0px)); padding: 2px 8px; } #pax b { font-size: 13px; } }
"""

PAX_JS = r"""
// ===== пассажиры и комфорт (как src/shared/Comfort.luau)
const COMF = { v: 100, pax: 0 };
function paxCount(c) {
  if (c.id === "F16") return 0; if (c.engines === "prop") return 3;
  if (c.length < 130 && c.diameter < 11) return Math.max(6, Math.round(c.length * 0.12));
  return Math.round(c.length * (c.diameter < 16 ? 1.3 : 1.35) * (c.doubleDeck ? 1.5 : 1));
}
function paxReset(cfg) { COMF.v = 100; COMF.pax = paxCount(cfg); }
function paxFrame(f, dt) {
  if (!f.onGround) {
    const right = new V3(1, 0, 0).applyQuaternion(f.att), bank = Math.abs(THREE.MathUtils.radToDeg(Math.asin(clamp(-right.y, -1, 1)))), vs = f.vel.y * 60 * FT;
    const pen = Math.max(0, bank - 30) * 0.05 + Math.max(0, Math.abs((f.gload || 1) - 1) - 0.35) * 10 + (Math.abs(vs) > 3000 ? 1.2 : 0) + (f.buffet || 0) * 5;
    COMF.v = clamp(COMF.v - pen * dt + (pen === 0 ? 0.15 * dt : 0), 0, 100);
  }
  const el = $("pax"); el.hidden = COMF.pax === 0 || f.crashed;
  if (!el.hidden) el.innerHTML = `<b style="color:${COMF.v >= 80 ? "var(--green)" : COMF.v >= 50 ? "var(--amber)" : "var(--red)"}">🧳 ${Math.round(COMF.v)}%</b><small>${COMF.pax} ПАСС.</small>`;
}
function paxTouchdown(text) { const fpm = (/(\d+) fpm/.exec(text) || [0, 0])[1] | 0; COMF.v = clamp(COMF.v - Math.max(0, fpm - 350) / 25, 0, 100); }
function paxStars(v) { const n = v >= 90 ? 5 : v >= 70 ? 4 : v >= 50 ? 3 : v >= 30 ? 2 : 1; return "★".repeat(n) + "☆".repeat(5 - n); }
"""


DOORS_JS = r"""  if (kind === "jet" && !cfg.fixedGear) {
    const doorM = std(col.body, { metal: 0.25, rough: 0.4 }), seamM = std(new THREE.Color(lin(col.body)).multiplyScalar(0.86).getHex(), { metal: 0.25, rough: 0.45 });
    const noseZ = -L / 2 + L * 0.12, mainY = Math.abs(mainX) > Rr * 0.6 ? wingY - rootC * 0.05 : -Rr * 0.6, bayY = Math.abs(mainX) > Rr * 0.6 ? wingY - rootC * 0.085 : -Rr * 0.62;
    for (const s of [-1, 1]) {
      const md = add(gear, new THREE.BoxGeometry(0.16, gh * 0.6, wD * 2.4), doorM, true); md.position.set(s * (mainX + wD * 1.0), mainY - gh * 0.32, mainZ);
      const nd = add(gear, new THREE.BoxGeometry(0.12, Rr * 0.34, wD * 2.2), doorM, true); nd.position.set(s * wD * 0.75, -Rr * 0.86, noseZ);
    }
    const doorsUp = new THREE.Group(); body.add(doorsUp); doorsUp.visible = false;
    for (const s of [-1, 1]) { const pnl = new THREE.Mesh(new THREE.BoxGeometry(wD * 2.6, 0.12, wD * 3.2), seamM); pnl.position.set(s * mainX, bayY, mainZ); doorsUp.add(pnl); }
    const np = new THREE.Mesh(new THREE.BoxGeometry(wD * 1.5, 0.1, wD * 2.6), seamM); np.position.set(0, -Rr * 0.97, noseZ); doorsUp.add(np);
    root.userData.doorsUp = doorsUp;
  }
"""


RAIN_JS = r"""// ===== дождь (как в Roblox): налетает раз в 5–12 минут, струи вокруг камеры, серое небо и дымка
const RAIN = { v: 0, t: 0, at: 120, clock: 0 };
const GREY_D = lin(0x9aa2ae), GREY_N = lin(0x1c2028);
let rainLines = null;
function rainSky(dt) {
  RAIN.clock += dt;
  if (RAIN.clock > RAIN.at) { RAIN.t = Math.random() < 0.45 ? 0.3 + Math.random() * 0.7 : 0; RAIN.at = RAIN.clock + 300 + Math.random() * 420; }
  RAIN.v += clamp(RAIN.t - RAIN.v, -0.004 * dt, 0.004 * dt);
  const r = RAIN.v; if (r < 0.01 && !rainLines) return;
  const day = clamp(Math.sin((gameClock - 6) / 24 * Math.PI * 2) * 3 + 0.25, 0, 1), grey = GREY_N.clone().lerp(GREY_D, day);
  ZENITH.lerp(grey, r * 0.75); HORIZON.lerp(grey, r * 0.7); GROUND_HAZE.lerp(grey, r * 0.5);
  sun.intensity *= 1 - 0.65 * r; hemi.intensity *= 1 - 0.3 * r; renderer.toneMappingExposure *= 1 - 0.18 * r; scene.fog.near = 2500 * (1 - 0.7 * r); scene.fog.far = 36000 * (1 - 0.62 * r);
  if (!rainLines) {
    const N = 1800, pos = new Float32Array(N * 6);
    for (let i = 0; i < N; i++) { const x = R(-120, 120), y = R(-60, 90), z = R(-120, 120); pos.set([x, y, z, x - 0.6, y - 7, z], i * 6); }
    const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    rainLines = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color: 0xc8d4e2, transparent: true, opacity: 0, depthWrite: false, fog: false }));
    rainLines.frustumCulled = false; scene.add(rainLines);
  }
  rainLines.visible = r > 0.05; rainLines.material.opacity = Math.min(0.55, r * 0.6);
  if (rainLines.visible) {
    const p = rainLines.geometry.attributes.position, a = p.array, fall = 160 * dt;
    for (let i = 0; i < a.length; i += 6) { a[i + 1] -= fall; a[i + 4] -= fall; if (a[i + 1] < -60) { a[i + 1] += 150; a[i + 4] += 150; } }
    p.needsUpdate = true; rainLines.position.copy(camera.position);
  }
}
"""


TERMINAL_JS = r"""  // терминал: крыша-волна со световыми фонарями, навес над подъездом, дорога, парковка с машинами
  { const roofM = std(0xd6dae0, { metal: 0.7, rough: 0.3 }), skyM = new THREE.MeshStandardMaterial({ color: lin(0x78aad2), metalness: 0.8, roughness: 0.1, envMap, transparent: true, opacity: 0.7 });
    for (let k = -4; k <= 4; k++) {
      const r = box(172, 1.6, 101, roofM, tx + 4, 45, k * 100, true); r.rotation.x = k % 2 === 0 ? 0.1 : -0.1;
      if (k < 4) box(150, 0.8, 6, skyM, tx + 4, 49.6, k * 100 + 50);
    }
    box(26, 1.4, 760, std(0xc8ccd4, { metal: 0.6, rough: 0.35 }), tx + 84, 21, 0, true);
    for (let z = -360; z <= 360; z += 80) box(2, 20, 2, std(0x969ca4, { metal: 0.7 }), tx + 94, 10.5, z, true);
    const road = std(0x34363a, { rough: 0.9 });
    box(34, 0.1, 1240, road, tx + 114, 0.52, 0);
    for (let z = -600; z <= 600; z += 36) box(0.8, 0.05, 14, paint, tx + 114, 0.58, z);
    box(170, 0.1, 620, std(0x3c3e42, { rough: 0.9 }), tx + 220, 0.52, 0);
    const cars = [], CARC = [0xebecee, 0x1c1e22, 0x969ca4, 0xa01e24, 0x1e468c, 0xd2d2c8];
    let seed = ap.id.charCodeAt(0) * 97; const rr = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    for (const rx of [165, 215, 265]) for (let z = -288; z <= 288; z += 16) {
      box(16, 0.05, 0.5, paint, tx + rx, 0.58, z - 8);
      if (rr() < 0.55) cars.push({ x: tx + rx + (rr() - 0.5) * 1.2, y: 2.2, z, sx: 8, sy: 3.2, sz: 4.4, color: CARC[Math.floor(rr() * CARC.length)] });
    }
    instanced(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({ metalness: 0.5, roughness: 0.3, envMap }), cars.map((it) => { const w = apToWorld(ap, it.x, it.z); return { ...it, x: w.x, z: w.z, ry: ap.rot ? Math.PI / 2 : 0 }; }), { shadow: true });
  }
"""


def add_premium(s, patch):
    # шрифты с кириллицей
    s = patch(s, "family=Russo+One&family=IBM+Plex+Mono:wght@500;600&family=IBM+Plex+Sans:wght@400;600",
              "family=Exo+2:ital,wght@0,600;0,700;0,800;1,900&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500;700")
    s = s.replace("IBM Plex Mono", "JetBrains Mono").replace("IBM Plex Sans", "Inter").replace('"Russo One"', '"Exo 2"').replace("Russo One", "Exo 2")
    # фиолетовый акцент → небесно-голубой (CSS, канвасы, 3D-маркеры)
    s = s.replace("#ff4fd8", ACCENT).replace("0xff4fd8", ACCENT_HEX).replace("rgba(255,79,216,", f"rgba({ACCENT_RGB},").replace("#1a0216", "#fff")
    s = s.replace("розовое кольцо", "голубое кольцо")
    # стили — последними, поверх всего
    s = patch(s, "</style>\n\n<div id=\"app\">", PREMIUM_CSS + "</style>\n\n<div id=\"app\">")
    # логотип в меню
    s = patch(s, '<div class="mwrap">\n      <div class="tiles">', BRAND_HTML)
    # актуальные новости и тексты
    a = s.index('      <div class="news">')
    b = s.index("      </div>", s.index('data-ph="mode_free"><b>Дубай', a)) + len("      </div>")
    s = s[:a] + NEWS_HTML + s[b:]
    s = patch(s, "<small>Любой самолёт, любой из 5 аэропортов</small>", "<small>Любой самолёт, любой из 8 аэропортов</small>")
    # фон меню/ангара — размытое фото, счёт в «чипе»
    s = patch(s, "  $(\"menu\").hidden = false;\n}",
              "  $(\"mChip\").innerHTML = `Очки <em>${SCORE.points.toLocaleString(\"ru-RU\")}</em> · посадок <em>${SCORE.landings}</em>`;\n"
              "  $(\"menu\").hidden = false;\n}\n"
              "if (PHOTOS.mode_free) $(\"menu\").style.setProperty(\"--hero\", `url(${PHOTOS.mode_free})`);\n"
              "if (PHOTOS.mode_career) $(\"flow\").style.setProperty(\"--hero\", `url(${PHOTOS.mode_career})`);")
    # подпись карточки самолёта — отдельным элементом поверх затемнения, с классом самолёта
    s = patch(s, 'b.className = "pcard"; b.style.backgroundImage = ph("plane_" + id); b.textContent = c.name;',
              'b.className = "pcard"; b.style.backgroundImage = ph("plane_" + id); b.innerHTML = `<span><small>${c.cls || ""}</small>${c.name}</span>`;')
    # справка: клавиши, добавленные позже (пробел, X, I) и геймпад
    s = patch(s, '<div><kbd>N</kbd> навигация: стрелка на аэропорт или город</div>',
              '<div><kbd>N</kbd> навигация: стрелка на аэропорт или город</div>\n'
              '        <div><kbd>Пробел</kbd> стояночный тормоз (на старте включён)</div>\n'
              '        <div><kbd>X</kbd> интерцепторы, <kbd>I</kbd> инструкция для самолёта</div>\n'
              '        <div style="grid-column: 1 / -1">Геймпад: стик — штурвал, R2/L2 — тяга, R1/L1 — руль, Y — шасси, крестовина — закрылки (↑↓), интерцепторы (←), навигация (→), X — реверс, B — тормоз, L3 — стояночный тормоз</div>')
    s = patch(s, "справа — рычаг тяги.", "справа — рычаг тяги, кнопки ИНТЕРЦ., ШАССИ, ЗАКР.")
    # фасады с окнами у обычных зданий городов (днём тёмное стекло, ночью часть окон светится)
    s = patch(s, '    neon: new THREE.MeshBasicMaterial({ color: 0xffffff }),\n  };\n  window.__cityMats = mats;',
              '    neon: new THREE.MeshBasicMaterial({ color: 0xffffff }),' + FACADE_JS + '\n  };\n  window.__cityMats = mats;')
    s = patch(s, ': p[11] === "Glass" ? (p[5] < 1 ? "water" : "glass") : "matte";',
              ': p[11] === "Glass" ? (p[5] < 1 ? "water" : "glass") : (p[0] === "box" && p[12] === 1 && p[5] >= 12 && Math.min(p[4], p[6]) >= 20 && p[2] - p[5] / 2 < 2) ? "facade" : "matte";')
    # стеклянные небоскрёбы ночью: свет по этажам и окнам, а не сплошной заливкой
    s = patch(s, "  window.__cityMats = mats;\n", """  window.__cityMats = mats;
  mats.glass.onBeforeCompile = (sh) => {
    sh.vertexShader = "varying vec3 vGP; varying vec3 vGN;\\n" + sh.vertexShader.replace("#include <project_vertex>", `#include <project_vertex>
      vec4 gwp = vec4(transformed, 1.0); vec3 gn = objectNormal;
      #ifdef USE_INSTANCING
        gwp = instanceMatrix * gwp; gn = mat3(instanceMatrix) * gn;
      #endif
      vGP = (modelMatrix * gwp).xyz; vGN = normalize(mat3(modelMatrix) * gn);`);
    sh.fragmentShader = "varying vec3 vGP; varying vec3 vGN;\\nfloat gh(vec2 p){ return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453); }\\n" +
      sh.fragmentShader.replace("#include <emissivemap_fragment>", `#include <emissivemap_fragment>
        float gside = 1.0 - step(0.6, abs(vGN.y));
        float ghc = abs(vGN.x) > abs(vGN.z) ? vGP.z : vGP.x;
        float gfx = fract(ghc / 5.0), gfy = fract(vGP.y / 5.5);
        float gwin = step(0.12, gfx) * step(gfx, 0.88) * step(0.22, gfy) * step(gfy, 0.86);
        float glit = step(0.35, gh(vec2(floor(ghc / 5.0), floor(vGP.y / 5.5))));
        totalEmissiveRadiance *= gside * gwin * mix(0.12, 1.0, glit);`);
  };
""")
    s = patch(s, "    if (g) g.emissive.copy(WARM).multiplyScalar(1.1 * n);", "    if (g) g.emissive.copy(WARM).multiplyScalar(1.1 * n);\n    if (window.__facadeU) window.__facadeU.uNight.value = n;")
    # отчёт о посадке (карточка вместо короткого уведомления)
    s = patch(s, '<div id="gm" hidden></div>', '<div id="gm" hidden></div>\n  <div id="lrep" hidden></div>')
    s = patch(s, "</style>\n\n<div id=\"app\">", LREP_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, "function scoreLanding(ap, text) {", LREP_JS + "function scoreLanding(ap, text) {")
    s = patch(s, "  addScore(pts, label);\n}\n\n// ===== смена дня", "  addScore(pts, label);\n  return pts;\n}\n\n// ===== смена дня")
    s = patch(s, 'toast(ev.text, ev.good ? "var(--green)" : "var(--amber)"); addLog(ev.text);', 'addLog(ev.text);')
    s = patch(s, "if (ap) scoreLanding(ap, ev.text);", "{ const __pts = ap ? scoreLanding(ap, ev.text) : 0; showLandingReport(f, ap, ev.text, __pts || 0); }")
    s = patch(s, '$("radar").hidden = true; $("gm").hidden = true;', '$("radar").hidden = true; $("gm").hidden = true; $("lrep").hidden = true;')
    # достижения: 12 целей, награда очками, экран в меню
    s = patch(s, "</style>\n\n<div id=\"app\">", ACH_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '  <div class="overlay" id="help" hidden>', ACH_HTML + '  <div class="overlay" id="help" hidden>')
    s = patch(s, '<button class="tb" id="mHelp2">Клавиши</button>', '<button class="tb" id="mHelp2">Клавиши</button><button class="tb" id="mAch">🏆 Достижения</button>')
    s = patch(s, "function scoreLanding(ap, text) {", ACH_JS + "function scoreLanding(ap, text) {")
    s = patch(s, "showLandingReport(f, ap, ev.text, __pts || 0); }", "showLandingReport(f, ap, ev.text, __pts || 0); achLanding(f, ap, ev.text); }")
    s = patch(s, 'if (ev.text.startsWith("Отрыв"))', 'if (ev.text.startsWith("Отрыв")) achUnlock("first_flight"); if (ev.text.startsWith("Отрыв"))')
    s = patch(s, '    physicsStep(f, input, dt);\n', '    physicsStep(f, input, dt);\n    achFrame(f);\n')
    s = patch(s, 'if (t >= 60) addScore(1500, "гонка колец");', 'if (t >= 60) { addScore(1500, "гонка колец"); achUnlock("race"); }')
    s = patch(s, '$("loading").hidden = true;', '$("mAch").onclick = () => { achRender(); $("achO").hidden = false; }; $("achClose").onclick = () => ($("achO").hidden = true); achRender();\n$("loading").hidden = true;')
    # самолёты: лаковая краска, «волна» ливреи к хвосту, стёкла кабины с рамками и бликом, металлическая передняя кромка
    s = patch(s, """    // хвостовая часть в цвет киля
    x.fillStyle = hex(cfg.colors.tail);""", """    // «волна»: полоса фирменного цвета поднимается от брюха к хвосту (на обе стороны)
    for (const side of [0, 1]) {
      const U = (u) => (side ? 1 - u : u) * W;
      const g = x.createLinearGradient(0, V(0.5), 0, V(0.12)); g.addColorStop(0, hex(cfg.colors.accent)); g.addColorStop(1, hex(cfg.colors.tail));
      x.fillStyle = g; x.beginPath();
      x.moveTo(U(0.47), V(0.52)); x.bezierCurveTo(U(0.42), V(0.36), U(0.3), V(0.22), U(0.08), V(0.12));
      x.lineTo(U(0.0), V(0.12)); x.lineTo(U(0.0), V(0.16)); x.bezierCurveTo(U(0.22), V(0.25), U(0.36), V(0.38), U(0.4), V(0.53)); x.closePath(); x.fill();
      x.fillStyle = "rgba(255,255,255,.9)"; x.beginPath();
      x.moveTo(U(0.4), V(0.53)); x.bezierCurveTo(U(0.36), V(0.38), U(0.22), V(0.25), U(0.0), V(0.16)); x.lineTo(U(0.0), V(0.17));
      x.bezierCurveTo(U(0.21), V(0.26), U(0.345), V(0.39), U(0.385), V(0.535)); x.closePath(); x.fill();
    }
    // хвостовая часть в цвет киля
    x.fillStyle = hex(cfg.colors.tail);""")
    s = patch(s, """      x.fillRect(W * 0.08, V(0.968), W * 0.15, 0.022 * H); x.fillRect(W * 0.77, V(0.968), W * 0.15, 0.022 * H);
      x.fillRect(0, V(0.975), W * 0.06, 0.018 * H); x.fillRect(W * 0.94, V(0.975), W * 0.06, 0.018 * H);""",
              """      // остекление кабины: 4 панели на сторону с рамками и бликом
      const pane = (u0, u1, v0, v1, k) => { const gr = x.createLinearGradient(0, V(v1), 0, V(v0)); gr.addColorStop(0, "#2c4a66"); gr.addColorStop(0.45, "#0d1622"); gr.addColorStop(1, "#060a10");
        x.fillStyle = gr; x.beginPath(); x.moveTo(W * u0, V(v0)); x.lineTo(W * u1, V(v0)); x.lineTo(W * (u1 - k), V(v1)); x.lineTo(W * (u0 + k), V(v1)); x.closePath(); x.fill();
        x.strokeStyle = "rgba(190,198,208,.9)"; x.lineWidth = 3; x.stroke(); };
      pane(0.0, 0.055, 0.958, 0.982, 0.004); pane(0.945, 1.0, 0.958, 0.982, 0.004);
      pane(0.06, 0.13, 0.956, 0.98, 0.006); pane(0.87, 0.94, 0.956, 0.98, 0.006);
      pane(0.135, 0.2, 0.953, 0.975, 0.008); pane(0.8, 0.865, 0.953, 0.975, 0.008);
      pane(0.205, 0.245, 0.951, 0.969, 0.006); pane(0.755, 0.795, 0.951, 0.969, 0.006);""")
    s = patch(s, """  return (liveryCache[cfg.id] = new THREE.MeshStandardMaterial({ map: t, metalness: kind === "fighter" ? 0.35 : 0.2, roughness: kind === "fighter" ? 0.55 : 0.32, envMap, envMapIntensity: 1 }));""",
              """  return (liveryCache[cfg.id] = kind === "fighter" ? new THREE.MeshStandardMaterial({ map: t, metalness: 0.35, roughness: 0.55, envMap, envMapIntensity: 1 })
    : new THREE.MeshPhysicalMaterial({ map: t, metalness: 0.15, roughness: 0.36, clearcoat: 1, clearcoatRoughness: 0.12, envMap, envMapIntensity: 1.05 }));""")
    s = patch(s, """  const tailMat = std(col.tail, { metal: 0.2, rough: 0.35, side: THREE.DoubleSide });""",
              """  const tailMat = kind === "fighter" ? std(col.tail, { metal: 0.2, rough: 0.35, side: THREE.DoubleSide })
    : new THREE.MeshPhysicalMaterial({ color: lin(col.tail), metalness: 0.15, roughness: 0.36, clearcoat: 1, clearcoatRoughness: 0.12, envMap, side: THREE.DoubleSide });""")
    # графика: звёзды и закатное свечение в небе, кучевые облака с тенью снизу, цвет облаков по времени суток
    s = patch(s, 'uniforms: { top: { value: ZENITH }, hor: { value: HORIZON }, gnd: { value: GROUND_HAZE }, sunDir: { value: SUN_DIR } },',
              'uniforms: { top: { value: ZENITH }, hor: { value: HORIZON }, gnd: { value: GROUND_HAZE }, sunDir: { value: SUN_DIR }, uNight: { value: 0 }, uDusk: { value: 0 } },')
    s = patch(s, '"uniform vec3 top; uniform vec3 hor; uniform vec3 gnd; uniform vec3 sunDir; varying vec3 vDir;",',
              '"uniform vec3 top; uniform vec3 hor; uniform vec3 gnd; uniform vec3 sunDir; uniform float uNight; uniform float uDusk; varying vec3 vDir;",'
              ' "float sh(vec3 p){ return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }",')
    s = patch(s, '" col += vec3(1.0,0.92,0.75) * pow(s, 900.0) * 30.0 + vec3(1.0,0.85,0.6) * pow(s, 12.0) * 0.35;",',
              '" col += vec3(1.0,0.92,0.75) * pow(s, 900.0) * 30.0 + vec3(1.0,0.85,0.6) * pow(s, 12.0) * 0.35;",'
              ' " col += vec3(1.0, 0.45, 0.2) * pow(s, 3.0) * uDusk * 0.55 * (1.0 - smoothstep(0.0, 0.45, abs(h)));",'
              ' " vec3 sq = floor(d * 520.0); float st = step(0.9982, sh(sq)) * smoothstep(0.02, 0.25, h) * uNight;",'
              ' " col += vec3(0.85, 0.9, 1.0) * st * (0.6 + 0.8 * sh(sq + 7.0));",')
    s = patch(s, """  const cloudMat = (o) => new THREE.SpriteMaterial({ map: puffTex, color: lin(0xffffff), transparent: true, opacity: o, depthWrite: false, fog: true });
  const cm1 = cloudMat(0.9), cm2 = cloudMat(0.55);
  for (let i = 0; i < 70; i++) {
    const cx = R(-23000, 23000), cz = R(-23000, 23000), cy = R(2600, 5200);
    const parts = 6 + Math.floor(rnd() * 6);
    for (let k = 0; k < parts; k++) {
      const s = new THREE.Sprite(k % 3 === 0 ? cm2 : cm1); const sz = R(380, 900);
      s.scale.set(sz * 1.6, sz, 1); s.position.set(cx + R(-700, 700), cy + R(-80, 140), cz + R(-500, 500)); scene.add(s);
    }
  }""", """  // кучевые облака: светлые «шапки» сверху, серое плоское основание; цвет меняется по времени суток (dayNight)
  const cloudMat = (o, c) => new THREE.SpriteMaterial({ map: puffTex, color: lin(c), transparent: true, opacity: o, depthWrite: false, fog: true });
  const cTop = cloudMat(0.95, 0xffffff), cMid = cloudMat(0.85, 0xe4e9f0), cBase = cloudMat(0.8, 0xc3ccd8), cWisp = cloudMat(0.35, 0xf4f6fa);
  window.__cloudMats = [[cTop, 0xffffff], [cMid, 0xe4e9f0], [cBase, 0xc3ccd8], [cWisp, 0xf4f6fa]];
  for (let i = 0; i < 70; i++) {
    const cx = R(-23000, 23000), cz = R(-23000, 23000), cy = R(2600, 5200), w = R(900, 1700);
    const parts = 7 + Math.floor(rnd() * 6);
    for (let k = 0; k < parts; k++) {          // основание: широкое, плоское, затенённое
      const s = new THREE.Sprite(cBase); const sz = R(420, 760); const a = rnd() * Math.PI * 2, rr = rnd() * w * 0.55;
      s.scale.set(sz * 1.9, sz * 0.75, 1); s.position.set(cx + Math.cos(a) * rr, cy - R(0, 40), cz + Math.sin(a) * rr * 0.7); scene.add(s);
    }
    for (let k = 0; k < parts; k++) {          // середина и купола: выше к центру
      const a = rnd() * Math.PI * 2, rr = rnd() * w * 0.42, up = (1 - rr / (w * 0.42)) * R(160, 360);
      const s = new THREE.Sprite(k % 2 ? cMid : cTop); const sz = R(420, 880);
      s.scale.set(sz * 1.25, sz, 1); s.position.set(cx + Math.cos(a) * rr, cy + 120 + up, cz + Math.sin(a) * rr * 0.7); scene.add(s);
    }
  }
  for (let i = 0; i < 26; i++) {               // высокие перистые облака
    const s = new THREE.Sprite(cWisp); const sz = R(1500, 3000);
    s.scale.set(sz * 3, sz * 0.35, 1); s.position.set(R(-26000, 26000), R(8500, 11000), R(-26000, 26000)); scene.add(s);
  }""")
    s = patch(s, "    if (window.__facadeU) window.__facadeU.uNight.value = n;",
              """    if (window.__facadeU) window.__facadeU.uNight.value = n;
    sky.material.uniforms.uNight.value = clamp((n - 0.35) / 0.65, 0, 1); sky.material.uniforms.uDusk.value = dusk;
    if (window.__cloudMats) for (const [m, c] of window.__cloudMats) { m.color.setHex(c).convertSRGBToLinear().lerp(lin(0xff9a6a), dusk * 0.45).multiplyScalar(0.16 + 0.84 * day); }""")
    # перрон: новые телетрапы, служебные машины, мачты освещения (как в WorldBuilder.luau)
    s = patch(s, """  // телетрапы к лайнерам
  for (const [id, z] of ap.parked) {
    const c = PLANES[id]; if (!c.windows || c.length < 100) continue;
    const doorX = W / 2 + 760 - c.length * 0.12, zb = z - c.diameter * 0.5 - 4, len = (tx - 70) - doorX;
    box(len, 8, 8, std(0xb8bec6, { metal: 0.5, rough: 0.4 }), doorX + len / 2, 0.5 + c.gearHeight + c.diameter * 0.1, zb, true);
    box(2, 0.5 + c.gearHeight + c.diameter * 0.1, 2, std(0x6b7078), doorX + len * 0.35, (0.5 + c.gearHeight + c.diameter * 0.1) / 2, zb);
  }""", APRON_JS)
    s = patch(s, "    if (window.__facadeU) window.__facadeU.uNight.value = n;",
              "    if (window.__facadeU) window.__facadeU.uNight.value = n;\n    if (window.__lampMat) window.__lampMat.emissiveIntensity = 2.6 * n;\n    if (window.__poolMat) window.__poolMat.opacity = 0.55 * n;")
    # ангар: карточка характеристик самолёта (полосы относительно лучшего в игре, ключевые цифры, fly-by-wire)
    s = patch(s, "</style>\n\n<div id=\"app\">", SPEC_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '    $("fText").textContent = c ? PLANE_TEXT(c) : "Выберите самолёт слева.";',
              '    if (c) $("fText").innerHTML = specHTML(c); else $("fText").textContent = "Выберите самолёт слева.";')
    s = patch(s, "const PLANE_TEXT = (c) =>", SPEC_JS + "const PLANE_TEXT = (c) =>")
    # ветер: снос самолёта в воздухе, порывы, ветер в разрешении диспетчера и на панели погоды (как в Roblox)
    s = patch(s, "  pos.addScaledVector(vel, dt);\n", "  pos.addScaledVector(vel, dt);\n  if (f.wind && !f.onGround) pos.addScaledVector(f.wind, dt);\n")
    s = patch(s, "const touch = { x: 0, y: 0, rl: 0, rr: 0, brake: false };\n", "const touch = { x: 0, y: 0, rl: 0, rr: 0, brake: false };\n" + WIND_JS)
    s = patch(s, "    const k = (c) => keys.has(c);\n", "    windStep(dt); f.wind = windVec();\n    const k = (c) => keys.has(c);\n")
    s = patch(s, "взлёт разрешён. Ветер штиль.`);", "взлёт разрешён. ${windPhrase(runwayFor(ap, flight.pos.x, flight.pos.z + 0))}`);")
    s = patch(s, "°C</small>`; }", "°C · ${WIND.kts < 2 ? \"штиль\" : \"ветер \" + String(Math.round(WIND.dir)).padStart(3, \"0\") + \"° \" + Math.round(WIND.kts) + \" kt\"}</small>`; }")
    # баг: оболочка мотогондолы (тело вращения) рисовалась только изнутри — делаем двустороннюю
    s = patch(s, "    const n = add(body, ng, engMat, true); n.position.copy(p);",
              "    const n = add(body, ng, window.__nacMat && window.__nacMat.userData.src === engMat ? window.__nacMat : (window.__nacMat = Object.assign(engMat.clone(), { side: THREE.DoubleSide, userData: { src: engMat } })), true); n.position.copy(p);")
    # двигатели: вращающийся вентилятор с лопатками и коком со спиралью, полированная губа, «шевроны» у 787
    s = patch(s, """    const fan = add(body, new THREE.CircleGeometry(eD * 0.42, 24), darkMat); fan.position.copy(p).add(new V3(0, 0, -eL / 2 + 0.25)); fan.rotation.y = Math.PI;
    const spin = add(body, new THREE.ConeGeometry(eD * 0.12, eD * 0.3, 16).rotateX(-Math.PI / 2), strutMat); spin.position.copy(p).add(new V3(0, 0, -eL / 2 + 0.2));""",
              FAN_JS)
    s = patch(s, "      if (u.prop) { u.prop.rotation.z += dt * (8 + f.throttle * 70);",
              "      if (u.fans) for (const r of u.fans) r.rotation.z += dt * (5 + f.throttle * 38);\n      if (u.prop) { u.prop.rotation.z += dt * (8 + f.throttle * 70);")
    # вода: бегущая рябь (нормали по мировым координатам), блики солнца — море, Босфор, Темза, озёра
    s = patch(s, "// города: Дубай, Лондон, Ташкент (данные общие с Roblox-версией, tools/gen_cities.py)\n{", WATER_JS + "// города: Дубай, Лондон, Ташкент (данные общие с Roblox-версией, tools/gen_cities.py)\n{")
    s = patch(s, "    water: new THREE.MeshStandardMaterial({ metalness: 0.4, roughness: 0.05, envMap, envMapIntensity: 1.3 }),",
              "    water: waveWater(new THREE.MeshStandardMaterial({ metalness: 0.4, roughness: 0.12, envMap, envMapIntensity: 1.3 })),")
    s = patch(s, "  const water = new THREE.MeshStandardMaterial({ color: lin(0x1f5a86), metalness: 0.35, roughness: 0.06, envMap, envMapIntensity: 1.2 });",
              "  const water = waveWater(new THREE.MeshStandardMaterial({ color: lin(0x1f5a86), metalness: 0.35, roughness: 0.12, envMap, envMapIntensity: 1.2 }));")
    s = patch(s, "function dayNight(dt) {\n", "function dayNight(dt) {\n  WATER_U.uTime.value += dt;\n")
    # огни подхода (ALS): стойки с 5 огнями до 900 stud, поперечины, красные боковые ряды, бегущие вспышки; синие огни рулёжек
    s = patch(s, """    for (let k = 1; k <= 10; k++) white.push({ x: 0, y: 0.75, z: e * (L / 2 + 60 * k), sx: 2, sy: 1.5, sz: 2 });
    white.push({ x: 0, y: 0.75, z: e * (L / 2 + 300), sx: 80, sy: 1.5, sz: 2 });""", ALS_JS)
    s = patch(s, "  const white = [], green = [], red = [];", "  const white = [], green = [], red = [], blue = [], poles = [], rabbit = [];")
    s = patch(s, "  for (let z = -L / 2; z <= L / 2; z += 125) for (const s of [-1, 1]) white.push({ x: s * (W / 2 + 3), y: 0.6, z, sx: 1.6, sy: 1.2, sz: 1.6 });",
              "  for (let z = -L / 2; z <= L / 2; z += 125) for (const s of [-1, 1]) white.push({ x: s * (W / 2 + 3), y: 0.6, z, sx: 1.6, sy: 1.2, sz: 1.6 });" + TAXI_BLUE_JS)
    s = patch(s, "  instanced(new THREE.BoxGeometry(1, 1, 1), basic(0xff3030), toW(red));",
              "  instanced(new THREE.BoxGeometry(1, 1, 1), basic(0xff3030), toW(red));" + ALS_INST_JS)
    s = patch(s, "function dayNight(dt) {\n", "function dayNight(dt) {\n  rabbitStep(dt);\n")
    s = patch(s, "function buildAirport(ap) {", RABBIT_JS + "function buildAirport(ap) {")
    # экран крушения: отчёт о полёте (статистика) и совет по причине
    s = patch(s, """      <h2>Крушение</h2>
      <p id="crashReason" style="margin-inline:auto"></p>""", """      <h2 style="color:var(--red)">💥 Крушение</h2>
      <p id="crashReason" style="margin-inline:auto;color:var(--fg);font-size:15px"></p>
      <div class="cstats" id="cStats"></div>
      <div class="ctip" id="cTip"></div>""")
    s = patch(s, "</style>\n\n<div id=\"app\">", CRASH_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, "function scoreLanding(ap, text) {", CRASH_JS + "function scoreLanding(ap, text) {")
    s = patch(s, "lastCfg = cfg; lastMode = mode;", "lastCfg = cfg; lastMode = mode; fstatsReset(cfg);")
    s = patch(s, "    achFrame(f);\n", "    achFrame(f); fstatsFrame(f, dt);\n")
    s = patch(s, "achLanding(f, ap, ev.text); }", "achLanding(f, ap, ev.text); FST.landings++; }")
    s = patch(s, 'if (crashTimer <= 0) $("crash").hidden = false; }', 'if (crashTimer <= 0) { fillCrash(); $("crash").hidden = false; } }')
    # пассажиры и комфорт (как src/shared/Comfort.luau)
    s = patch(s, "</style>\n\n<div id=\"app\">", PAX_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '<div id="gm" hidden></div>', '<div id="gm" hidden></div>\n  <div id="pax" hidden></div>')
    s = patch(s, "// ===== статистика полёта и совет после крушения", PAX_JS + "// ===== статистика полёта и совет после крушения")
    s = patch(s, "function fstatsReset(cfg) {", "function fstatsReset(cfg) { paxReset(cfg);")
    s = patch(s, "function fstatsFrame(f, dt) {", "function fstatsFrame(f, dt) { paxFrame(f, dt);")
    s = patch(s, "showLandingReport(f, ap, ev.text, __pts || 0);", "paxTouchdown(ev.text); showLandingReport(f, ap, ev.text, __pts || 0);")
    s = patch(s, '$("radar").hidden = true; $("gm").hidden = true;', '$("radar").hidden = true; $("gm").hidden = true; $("pax").hidden = true;')
    # створки шасси: открытые у стоек (в группе шасси), закрытые панели под фюзеляжем и крылом — когда шасси убрано
    s = patch(s, '  leg(0, -L / 2 + L * 0.12, kind === "light" ? 1 : 2, 1);\n', '  leg(0, -L / 2 + L * 0.12, kind === "light" ? 1 : 2, 1);\n' + DOORS_JS)
    s = patch(s, "u.gear.scale.y = Math.max(0.001, gearAnim); u.gear.visible = gearAnim > 0.02;",
              "u.gear.scale.y = Math.max(0.001, gearAnim); u.gear.visible = gearAnim > 0.02; if (u.doorsUp) u.doorsUp.visible = gearAnim < 0.05;")
    # дождь: струи вокруг камеры, серое небо и дымка, хуже видимость, тусклое солнце; на панели погоды
    s = patch(s, "function dayNight(dt) {", RAIN_JS + "function dayNight(dt) {")
    s = patch(s, "  renderer.toneMappingExposure = 0.42 + 0.63 * day;\n", "  renderer.toneMappingExposure = 0.42 + 0.63 * day;\n  rainSky(dt);\n  scene.fog.color.copy(HORIZON);\n")
    s = patch(s, 'el.innerHTML = `${ic} ${ph} · ', 'el.innerHTML = `${RAIN.v > 0.15 ? "🌧" : ic} ${ph} · ')
    s = patch(s, " + \" kt\"}</small>`; }", " + \" kt\"}${RAIN.v > 0.6 ? \" · ливень\" : RAIN.v > 0.15 ? \" · дождь\" : \"\"}</small>`; }")
    # терминал: крыша-волна, навес, дорога и парковка с машинами (как в WorldBuilder.luau)
    s = patch(s, "  addLocalRect(ap, W / 2 + 280, W / 2 + 880, -1500, -1000, 0.49);\n", "  addLocalRect(ap, W / 2 + 280, W / 2 + 880, -1500, -1000, 0.49);\n  addLocalRect(ap, W / 2 + 880, W / 2 + 1320, -700, 700, 0.49);\n")
    s = patch(s, "  // вышка\n", TERMINAL_JS + "  // вышка\n")
    # геймпад в веб-версии (раньше работал только в Roblox)
    s = patch(s, "const touch = { x: 0, y: 0, rl: 0, rr: 0, brake: false };", "const touch = { x: 0, y: 0, rl: 0, rr: 0, brake: false };\n" + GAMEPAD_JS)
    s = patch(s, """    const k = (c) => keys.has(c);
    const input = {
      p: ((k("KeyS") || k("ArrowDown")) ? 1 : 0) - ((k("KeyW") || k("ArrowUp")) ? 1 : 0) + touch.y,
      r: ((k("KeyD") || k("ArrowRight")) ? 1 : 0) - ((k("KeyA") || k("ArrowLeft")) ? 1 : 0) + touch.x,
      y: (k("KeyE") ? 1 : 0) - (k("KeyQ") ? 1 : 0) + touch.rr - touch.rl,
      thrUp: k("ShiftLeft") || k("ShiftRight"), thrDn: k("ControlLeft") || k("ControlRight"),
      brakes: k("KeyB") || touch.brake || (parkBrake && f.onGround),""", """    const k = (c) => keys.has(c);
    padPoll();
    const input = {
      p: clamp(((k("KeyS") || k("ArrowDown")) ? 1 : 0) - ((k("KeyW") || k("ArrowUp")) ? 1 : 0) + touch.y + PAD.p, -1, 1),
      r: clamp(((k("KeyD") || k("ArrowRight")) ? 1 : 0) - ((k("KeyA") || k("ArrowLeft")) ? 1 : 0) + touch.x + PAD.r, -1, 1),
      y: clamp((k("KeyE") ? 1 : 0) - (k("KeyQ") ? 1 : 0) + touch.rr - touch.rl + PAD.y, -1, 1),
      thrUp: k("ShiftLeft") || k("ShiftRight") || PAD.up, thrDn: k("ControlLeft") || k("ControlRight") || PAD.dn,
      brakes: k("KeyB") || touch.brake || PAD.brake || (parkBrake && f.onGround),""")
    return s
