# ⏸ Меню паузы (веб): Esc или кнопка «⏸» — самолёт замирает; окно со сводкой текущего полёта и кнопками
# «Продолжить», «Начать заново», «Настройки», «Инструкция», «В меню». В Roblox то же (` или «⏸»).
PAUSE_HTML = """  <div class="overlay" id="pauseO" style="z-index:38" hidden>
    <div class="sheet" style="max-width:440px">
      <h2>❚❚ Пауза</h2>
      <div class="logtot" id="pauseSum" style="grid-template-columns:repeat(2,1fr)"></div>
      <div class="pbtns"><button class="tb primary" id="pResume">▶ Продолжить <small>Esc</small></button><button class="tb" id="pAgain">↻ Начать полёт заново</button>
        <button class="tb" id="pSet">⚙ Настройки</button><button class="tb" id="pGuide">📖 Инструкция</button><button class="tb" id="pMenu">✈ В меню</button></div>
    </div>
  </div>
  <style>.pbtns { display: grid; gap: 8px; margin-top: 6px; } .pbtns .tb { width: 100%; justify-content: center; font-size: 15px; padding: 11px 16px; } .pbtns small { opacity: .6; margin-left: 6px; font-size: 11px; }</style>
"""

PAUSE_JS = r"""
// ===== пауза
var PAUSE = false;
function togglePause(on) {
  if (!flight || flight.crashed) on = false;
  PAUSE = on === undefined ? !PAUSE : on; $("pauseO").hidden = !PAUSE;
  if (PAUSE) { const cell = (v, k) => `<div><b>${v}</b><small>${k}</small></div>`;
    $("pauseSum").innerHTML = cell(flight.cfg.name.replace(/^(Boeing|Airbus|Bombardier|Gulfstream|Cessna) /, ""), "самолёт") + cell(fmtMS(Math.round(FST.time)), "в воздухе") + cell(FST.landings, "посадок") + cell("+" + fmt(Math.max(0, SCORE.points - FST.startPts)), "очки за полёт"); }
}
$("pResume").onclick = () => togglePause(false);
$("pAgain").onclick = () => { togglePause(false); if (lastCfg) { flightDest = lastDest; startFlight(lastCfg, lastMode); } };
$("pSet").onclick = () => { renderSettings(); $("setO").hidden = false; };
$("pGuide").onclick = () => { if (flight) showGuide(flight.cfg); };
$("pMenu").onclick = () => { togglePause(false); openMenu(); };
addEventListener("keydown", (e) => { if (e.code === "Escape" && !e.repeat) { if (!$("setO").hidden) $("setO").hidden = true; else if (flight && !flight.crashed && $("menu").hidden && $("flow").hidden) togglePause(); } });
"""

def add_pause(s, patch):
    s = patch(s, '  <div class="overlay" id="setO" style="z-index:40" hidden>', PAUSE_HTML + '  <div class="overlay" id="setO" style="z-index:40" hidden>')
    s = patch(s, "  if (f && !f.crashed && !PHOTO) {\n", "  if (f && !f.crashed && !PHOTO && !PAUSE) {\n")
    s = patch(s, '$("loading").hidden = true;', PAUSE_JS + '$("bPhoto") && $("bPhoto").insertAdjacentHTML("beforebegin", \'<button class="tb" id="bPause">❚❚ Пауза</button>\'); $("bPause") && ($("bPause").onclick = () => togglePause());\n$("loading").hidden = true;')
    s = patch(s, "function doCrash(reason) {\n", "function doCrash(reason) {\n  if (PAUSE) togglePause(false);\n")
    return s
