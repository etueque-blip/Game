# Полоса маршрута в режиме рейсов (веб): ВЫЛЕТ ——✈—— НАЗНАЧЕНИЕ, самолётик движется по доле пройденного пути,
# остаток (км), расчётное время прибытия при текущей скорости и подсказка «пора снижаться» (ближе ~2,3 км и выше 2000 ft).
# В Roblox то же — Ui.setRoute.
ROUTE_CSS = """
#route { position: absolute; left: 50%; bottom: calc(20px + env(safe-area-inset-bottom, 0px)); transform: translateX(-50%); width: min(560px, calc(100% - 300px)); min-width: 300px;
  background: var(--glass, rgba(14,20,34,0.72)); border: 1px solid var(--line); border-radius: 16px; padding: 10px 16px 9px; box-shadow: var(--shadow); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); pointer-events: none; z-index: 3; }
#route .rt { display: flex; align-items: center; gap: 12px; } #route .ap { font-family: var(--f-display, inherit); font-weight: 800; font-size: 17px; letter-spacing: .04em; }
#route .ap small { display: block; font-size: 10px; font-weight: 600; color: var(--dim); letter-spacing: .08em; }
#route .tr { position: relative; flex: 1; height: 4px; border-radius: 2px; background: rgba(255,255,255,0.14); }
#route .fill { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 2px; background: linear-gradient(90deg, #3ba7ff, #3ddc84); }
#route .pl { position: absolute; top: 50%; transform: translate(-50%, -54%) rotate(90deg); font-size: 18px; filter: drop-shadow(0 2px 3px rgba(0,0,0,.5)); }
#route .info { display: flex; justify-content: space-between; gap: 10px; margin-top: 7px; font-family: var(--f-num, ui-monospace, monospace); font-size: 12px; color: var(--dim); }
#route .info b { color: var(--fg, #fff); font-weight: 700; } #route .tod { color: var(--amber, #f5a524); font-weight: 700; }
@media (max-height: 480px) { #route { bottom: calc(8px + env(safe-area-inset-bottom, 0px)); width: min(380px, calc(100% - 340px)); min-width: 240px; padding: 6px 12px; } #route .ap { font-size: 13px; } #route .ap small { display: none; } #route .info { margin-top: 4px; font-size: 11px; } }
@media (pointer: coarse) and (min-height: 481px) { #route { bottom: auto; top: calc(200px + env(safe-area-inset-top, 0px)); width: min(380px, calc(100% - 24px)); min-width: 0; padding: 7px 12px; } }
"""

ROUTE_JS = r"""
// ===== полоса маршрута (режим рейсов)
function drawRoute(f) {
  const el = $("route"), to = flightDest && AIRPORTS.find((a) => a.id === flightDest), from = scoreFrom && AIRPORTS.find((a) => a.id === scoreFrom);
  if (!to || !from || f.crashed || PHOTO) { el.hidden = true; return; } el.hidden = false;
  const total = Math.hypot(to.cx - from.cx, to.cz - from.cz), rem = Math.hypot(to.cx - f.pos.x, to.cz - f.pos.z), frac = clamp(1 - rem / Math.max(1, total), 0, 1);
  const km = rem * 0.515 / 1000, eta = f.speed > 20 ? rem / f.speed : null, nm = rem * 0.515 / 1852, altFt = f.pos.y * FT;
  const tod = !f.onGround && altFt > 2000 && rem < 4500 && rem > 1500;
  if (!el.firstChild) el.innerHTML = `<div class="rt"><div class="ap" id="rFrom"></div><div class="tr"><div class="fill" id="rFill"></div><div class="pl" id="rPl">✈</div></div><div class="ap" id="rTo" style="text-align:right"></div></div><div class="info"><span id="rRem"></span><span id="rTod" class="tod"></span><span id="rEta"></span></div>`;
  $("rFrom").innerHTML = `${from.code}<small>ВЫЛЕТ</small>`; $("rTo").innerHTML = `${to.code}<small>${to.region || "ПРИЛЁТ"}</small>`;
  $("rFill").style.width = (frac * 100).toFixed(1) + "%"; $("rPl").style.left = (frac * 100).toFixed(1) + "%";
  $("rRem").innerHTML = `осталось <b>${km < 10 ? km.toFixed(1) : Math.round(km)} км</b>`;
  $("rEta").innerHTML = eta === null ? "на земле" : `прибытие через <b>${Math.floor(eta / 60)}:${String(Math.floor(eta % 60)).padStart(2, "0")}</b>`;
  $("rTod").textContent = tod ? "↘ пора снижаться" : rem < 1500 ? "заход на посадку" : "";
}
"""

def add_route(s, patch):
    s = patch(s, "</style>\n\n<div id=\"app\">", ROUTE_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '<div id="nav" hidden></div>', '<div id="nav" hidden></div>\n  <div id="route" hidden></div>')
    s = patch(s, "function updateHUD(f) {", ROUTE_JS + "function updateHUD(f) {")
    s = patch(s, "drawTape(hdg); drawPFD(f); acroTick(f);\n", "drawTape(hdg); drawPFD(f); acroTick(f); drawRoute(f);\n")
    s = patch(s, '$("htape").hidden = true; $("spdT").hidden = true;', '$("htape").hidden = true; $("route").hidden = true; $("spdT").hidden = true;')
    return s
