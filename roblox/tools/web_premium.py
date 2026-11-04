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
        <div class="ncard" data-ph="mode_career"><span class="tag">Новое</span><b>Перегрузка G и fly-by-wire</b><i>Пределы конструкции, тряска, поломки закрылков и шасси</i></div>
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
